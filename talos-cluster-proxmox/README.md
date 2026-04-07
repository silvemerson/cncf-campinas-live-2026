# talos-cluster-proxmox

Terraform para provisionar um cluster Kubernetes HA com Talos Linux no Proxmox VE.

3 control planes + 3 workers, criados do zero via IaC — sem templates para clonar, sem intervenção manual após o `terraform apply`.

---

## Arquitetura

```
talos-cluster-proxmox/
├── modules/
│   ├── vm-talos/          # cria cada VM no Proxmox (disco + ISO + machineconfig)
│   └── talos-cluster/     # gera secrets do cluster + machineconfig por nó
└── prod/                  # ambiente de produção
    ├── main.tf
    ├── variables.tf
    ├── output.tf
    ├── backend.tf
    ├── backend.hcl
    ├── terraform.tfvars
    └── terraform.tfvars.example
```

### Providers

| Provider | Versão | Finalidade |
|---|---|---|
| `bpg/proxmox` | 0.96.0 | Cria VMs, snippets e faz upload de arquivos no Proxmox |
| `siderolabs/talos` | 0.7.1 | Gera secrets do cluster, machineconfigs, faz bootstrap e recupera kubeconfig |

---

## Pré-requisitos

### Proxmox

- Proxmox VE 8.x
- API token com permissões de criação de VMs:
  ```
  pveum user token add root@pam terraform-token
  pveum aclmod / -user root@pam -role Administrator
  ```
- Datastore `local` com content type **Snippets** habilitado:
  - Proxmox UI → Datacenter → Storage → local → Edit → Content → marcar **Snippets**

### Imagem Talos

Gerar a imagem com `qemu-guest-agent` em [factory.talos.dev](https://factory.talos.dev):

1. Platform: `nocloud`
2. Extensions: `siderolabs/qemu-guest-agent`
3. Copiar o **Schematic ID** gerado

Baixar a ISO no node Proxmox:

```bash
wget -O /var/lib/vz/template/iso/nocloud-amd64.iso \
  "https://factory.talos.dev/image/<SCHEMATIC_ID>/v1.12.6/nocloud-amd64.iso"
```

> A ISO nocloud é necessária (não a metal). O Talos lê o machineconfig via cloud-init user-data no primeiro boot.

---

## Configuração da VM (decisões importantes)

Durante o desenvolvimento foram testadas diversas combinações. A configuração que funcionou:

| Parâmetro | Valor | Motivo |
|---|---|---|
| Machine type | `q35` | Suporte a PCIe moderno, necessário para virtio-scsi |
| BIOS | SeaBIOS (padrão) | OVMF/UEFI causava crash com `QEMU exited with code 1` no Proxmox 8 |
| Disk controller | `virtio-scsi-pci` | Não usar `virtio-scsi-single` — causa hangs no bootstrap (issue siderolabs#11173) |
| Disk interface | `scsi0` | Compatível com q35 + virtio-scsi-pci |
| CDROM interface | `ide0` | `ide3` causa erro: "Can't create IDE unit 1, bus supports only 1 units" no q35 |
| Cloud-init | `ide2` (automático) | Gerado pelo provider bpg/proxmox, ocupa ide.1 unit 0 |
| Disco formato | `raw` | Performance |

### Por que não usar clone de template?

Tentamos clonar um template com a imagem raw do Talos. O problema: ao clonar, o provider tenta redimensionar o disco mas a API do Proxmox retorna erro. Criar as VMs do zero (sem clone) elimina essa dependência e é mais simples.

### Por que SeaBIOS e não UEFI?

O UEFI (OVMF) no Proxmox usa `OVMF_CODE_4M.secboot.fd` por padrão (Secure Boot). Com o EFI disk sem chaves pré-enrolladas e a imagem Talos, o QEMU crashava com código 1 antes de bootar. SeaBIOS funciona perfeitamente com a ISO nocloud do Talos.

---

## Fluxo de provisionamento

```
terraform apply
    │
    ├── module.talos_cluster
    │   ├── gera PKI + secrets do cluster (talos_machine_secrets)
    │   └── gera machineconfig por nó com IP estático + installer image
    │
    ├── module.controlplane (for_each: 3 nós)
    │   ├── faz upload do machineconfig como snippet no Proxmox
    │   └── cria VM: disco vazio (scsi0) + ISO (ide0) + cloud-init com machineconfig
    │
    ├── module.worker (for_each: 3 nós)
    │   └── idem
    │
    ├── talos_machine_bootstrap
    │   └── inicializa etcd no primeiro controlplane
    │
    └── data.talos_cluster_kubeconfig
        └── recupera kubeconfig após bootstrap
```

### Boot de cada VM

1. SeaBIOS tenta bootar `scsi0` → disco vazio → falha
2. Cai para `ide0` (ISO) → menu GRUB → Talos ISO
3. Talos lê machineconfig do drive cloud-init (`ide2`)
4. Aplica configuração de rede (IP estático) + instala no `scsi0`
5. Reinicia → bota do `scsi0` → nó sobe com IP e config corretos

---

## Uso

### 1. Copiar e preencher as variáveis

```bash
cp prod/terraform.tfvars.example prod/terraform.tfvars
```

Editar `terraform.tfvars` com os valores do seu ambiente.

### 2. Inicializar e aplicar

```bash
cd prod/
terraform init -backend-config=backend.hcl
terraform plan
terraform apply
```

### 3. Exportar as configs

```bash
terraform output -raw talosconfig > ~/.talos/config
terraform output -raw kubeconfig > ~/.kube/config
```

### 4. Verificar o cluster

```bash
kubectl get nodes
talosctl health --nodes 192.168.1.201
```

### 5. Instalar CNI

O Talos não vem com CNI. Instalar Flannel (ou outro de preferência):

```bash
kubectl apply -f https://github.com/flannel-io/flannel/releases/latest/download/kube-flannel.yml
```

Após 1-2 minutos todos os nós ficam `Ready`.

---

## Variáveis principais

### Proxmox

| Variável | Descrição |
|---|---|
| `proxmox_endpoint` | URL da API, ex: `https://192.168.1.155:8006` |
| `proxmox_api_token_id` | Token no formato `user@realm!token` |
| `proxmox_api_token_secret` | Secret do token |
| `target_node` | Nome do node Proxmox |
| `disk_storage` | Datastore para os discos das VMs (ex: `local-lvm`) |
| `snippets_datastore` | Datastore com content type Snippets habilitado (ex: `local`) |

### Talos

| Variável | Descrição |
|---|---|
| `talos_version` | Versão do Talos sem `v` (ex: `1.12.6`) |
| `talos_schematic_id` | Schematic ID gerado no factory.talos.dev |
| `talos_iso_id` | Referência da ISO no Proxmox (ex: `local:iso/nocloud-amd64.iso`) |

### Cluster

| Variável | Descrição |
|---|---|
| `cluster_name` | Nome do cluster Kubernetes |
| `controlplane_ips` | Lista com 3 IPs estáticos para os control planes |
| `worker_ips` | Lista com os IPs dos workers |
| `network_gateway_ipv4` | Gateway padrão da rede |
| `network_prefix` | Prefixo da subnet (ex: `24` para /24) |
| `controlplane_vip` | VIP opcional para HA do API server (deixar vazio para usar o IP do primeiro CP) |

### Specs das VMs

| Variável | Padrão | Descrição |
|---|---|---|
| `controlplane_cores` | `2` | vCPUs dos control planes |
| `controlplane_memory_mb` | `4096` | RAM dos control planes (mínimo recomendado) |
| `controlplane_disk_gb` | `20` | Disco dos control planes |
| `worker_cores` | `4` | vCPUs dos workers |
| `worker_memory_mb` | `8192` | RAM dos workers (mínimo recomendado) |
| `worker_disk_gb` | `20` | Disco dos workers |

---

## State remoto

O state é armazenado no MinIO (`rustfs.silvalabs.local`), compatível com backend S3.

Inicializar com:
```bash
terraform init -backend-config=backend.hcl
```

`backend.hcl` contém as credenciais do MinIO — não commitar.

---

## Observações

- O machineconfig inclui o installer image do factory com `qemu-guest-agent`, garantindo integração com o Proxmox (IP via guest agent, trim de disco)
- O campo `ignore_changes = [initialization, cdrom]` é necessário: após o primeiro boot o Talos gerencia sua própria config e o CDROM não é mais relevante
- Destruir o recurso `talos_machine_secrets` força rebuild completo do cluster — os secrets são a raiz de confiança do cluster
