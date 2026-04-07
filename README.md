# Talos Linux + Proxmox + Terraform: infraestrutura declarativa on-premises

Slides da palestra apresentada no **CNCF Campinas · 2026**.

🔗 [Página do evento](https://community.cncf.io/events/details/cncf-cloud-native-campinas-presents-cncf-campinas-sp-meetup-online-kubernetes-platform-amp-ia-1/)

---

<img src="logos-cncf/fundo-transparente.png" height="200">


## Whoami

**Emerson Silva**

- Engenheiro DevOps/SRE na **4Linux**
- +9 anos em ambientes DevOps críticos
- Foco em **Kubernetes**, IaC e confiabilidade
- Escritor, instrutor e palestrante ativo na comunidade
- Blog: [emerson-silva.blog.br](https://emerson-silva.blog.br)

---

## O que será visto na palestra

1. **O problema com o OS tradicional** — configuration drift, SSH como superfície de ataque e a fragilidade dos scripts de cloud-init
2. **O que é o Talos Linux** — filosofia, design e os quatro pilares: API managed, imutável, minimal e secure by default
3. **Arquitetura e filosofia** — `machined` como PID 1, sistema de arquivos em camadas (SquashFS + overlayfs), partições e configuração declarativa via MachineConfig
4. **Segurança e atualizações** — mTLS obrigatório, RBAC por certificado, atualizações atômicas com esquema de boot A/B e rollback automático
5. **Armazenamento no Talos** — opções CSI (Longhorn, Rook+Ceph, OpenEBS Mayastor), armazenamento em nuvem e bare metal, dimensionamento do control plane
6. **Demo ao vivo** — cluster Kubernetes HA com 3 control planes e 3 workers provisionado do zero via `terraform apply` no Proxmox, sem nenhuma intervenção manual
7. **Quando faz sentido usar** — casos de uso ideais e limitações honestas

---

## Código da demo

O Terraform usado na demo está em [`talos-cluster-proxmox/`](talos-cluster-proxmox/):

```
talos-cluster-proxmox/
├── modules/
│   ├── vm-talos/       ← cria cada VM no Proxmox
│   └── talos-cluster/  ← gera configs e segredos do Talos
└── prod/               ← ambiente de produção
```

Providers: `bpg/proxmox` (cria as VMs) + `siderolabs/talos` (gera secrets, machineconfigs, bootstrap e kubeconfig).

---

## Como usar os slides

### Pré-requisito

```bash
npm install -g @marp-team/marp-cli
```

### Visualizar no browser com live reload

```bash
marp --watch talos-linux-dougbr.md
```

### Abrir o HTML já gerado

```bash
xdg-open talos-linux-dougbr.html
```

### Exportar para PDF

```bash
marp talos-linux-dougbr.md --pdf --allow-local-files -o talos-linux-dougbr.pdf
```

> `--allow-local-files` é necessário para carregar imagens e logos locais.

### Exportar para HTML

```bash
marp talos-linux-dougbr.md --html --allow-local-files -o talos-linux-dougbr.html
```

---

## Recursos

- Documentação oficial: [docs.siderolabs.com](https://docs.siderolabs.com)
- Repositório Talos: [github.com/siderolabs/talos](https://github.com/siderolabs/talos)
- Provider bpg/proxmox: [registry.terraform.io/providers/bpg/proxmox](https://registry.terraform.io/providers/bpg/proxmox)
- Provider siderolabs/talos: [registry.terraform.io/providers/siderolabs/talos](https://registry.terraform.io/providers/siderolabs/talos)
- Blog do autor: [emerson-silva.blog.br](https://emerson-silva.blog.br)
