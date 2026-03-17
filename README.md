# Projeto de Infraestrutura e Plataforma Kubernetes (K3s) em Alta Disponibilidade na OCI

Este projeto foi desenvolvido como entrega técnica com o objetivo de demonstrar:

- Capacidade de desenhar e implementar infraestrutura de nuvem do zero na Oracle Cloud Infrastructure (OCI).
- Uso consistente de Infraestrutura como Código (IaC) e Automação de Configuração.
- Boas práticas de segurança, observabilidade e gerenciamento de estado.
- Conhecimento prático de Kubernetes (K3s), CI/CD, DNS Dinâmico e Automação TLS

Todo o ambiente foi construído provisionando máquinas virtuais (IaaS) em vez de utilizar um cluster gerenciado (como OKE ou AKS), demonstrando controle total, entendimento de arquitetura de base e reprodutibilidade.

---

> ### Observação sobre o ambiente
>
> Este ambiente foi construído com foco em **demonstração técnica** e **boas práticas arquiteturais**.
>
> Embora utilize padrões próximos aos de produção, a escolha por instâncias ARM (VM.Standard.E5.Flex) e o uso de DNS dinâmico foram ajustados para o contexto de viabilidade e avaliação técnica.
>
> As decisões adotadas priorizam clareza, automação end-to-end, reprodutibilidade e aderência a boas práticas, lidando com os desafios reais de subir e configurar um cluster do zero.

---

## 1. Infraestrutura

### 1.1 Escolha da abordagem

A infraestrutura foi a primeira etapa, pois todo o restante do projeto (Kubernetes, CI/CD, Ingress, TLS, Observabilidade) depende diretamente dela.

Foi adotado o conceito de Infraestrutura como Código (IaC) associado ao Gerenciamento de Configuração para garantir:

- Reprodutibilidade
- Versionamento
- Clareza arquitetural
- Automação da instalação
- Facilidade de auditoria técnica

---

## 2. Ferramenta de Infraestrutura

### Terraform e Ansible

1. Terraform foi escolhido como ferramenta principal de IaC (Provisionamento), pois:

- Padrão de mercado para criação de recursos de nuvem.
- Provider oficial para Oracle Cloud (oci).
- Sintaxe declarativa para criar Redes (VCN), Subnets, Regras de Segurança e Instâncias Compute.

2. Ansible foi escolhido para Gerenciamento de Configuração (Bootstrap), pois:

- Permite orquestrar a instalação do Kubernetes (K3s) de forma idempotente.
- Gerencia a complexidade de extrair o token do Master e injetar nos Workers.
- Prepara o sistema operacional (ex: desabilitando Firewall nativo).

O que não foi utilizado (intencionalmente):

Serviço de Kubernetes Gerenciado (OKE/AKS/EKS)
→ O objetivo era demonstrar a capacidade de construir o cluster a partir do IaaS.
Provisionamento manual
→ Não auditável, sujeito a erros humanos.


---

## 3. Estrutura do Repositório de Infra

A estrutura foi desenhada para refletir responsabilidades claras (árvore de diretórios):

projeto-k8s-ha/
├── .github/
│   └── workflows/
│       └── terraform-deploy.yml
├── config/
│   └── ansible/
│       ├── get_helm.sh
│       ├── inventory.ini          # Inventário dinâmico gerado pelo Terraform
│       ├── k3s-install.yml        # Playbook de bootstrap do cluster
│       └── k3s.yaml               # Kubeconfig gerado
├── infra/
│   └── terraform/
│       ├── .terraform.lock.hcl
│       ├── compute.tf             # Definição das VMs e geração do inventory.ini
│       ├── network.tf             # VCN e Subnets
│       ├── outputs.tf
│       ├── provider.tf
│       ├── security.tf            # Security Lists / regras de firewall
│       ├── terraform.tfvars
│       ├── variables.tf
│       └── versions.tf
├── k8s/
│   ├── app/
│   │   └── whoami.yaml            # Deployment da aplicação de teste
│   └── ingress/
│       ├── cluster-issuer.yaml    # Configuração do Let's Encrypt
│       └── whoami-ingress.yaml    # Configuração de rota DNS/TLS da aplicação
├── loki-ds.yaml                   # Correções de datasource da stack de logs
├── loki-fix.yaml                  # Configuração Helm customizada do Promtail
└── .gitignore

---

## 4. Backend de Estado (Terraform State)

O estado do Terraform foi gerenciado considerando pipelines automatizados. O pipeline .github/workflows/terraform-deploy.yml injeta credenciais (AWS_ACCESS_KEY_ID, AWS_SECRET_ACCESS_KEY), indicando o uso de um backend remoto compatível com S3 para armazenar o terraform.tfstate, garantindo:

- Consistência entre execuções do GitHub Actions.
- Evita perda de estado ou conflitos operacionais.

---

## 5. Recursos Criados via Terraform

### 5.1 Recursos principais

- Resource Group
- Virtual Network (VNet)
- Subnets
- Security Lists para controle de tráfego

---

## 6.  K3s — Kubernetes Distribuído e Leve

### Por que K3s em bare-VMs?

- Distribuição Kubernetes certificada, altamente otimizada e pronta para produção.
- Diferente de soluções gerenciadas, exige conhecimento profundo de orquestração de nós, comunicação interna e injeção de tokens.

*Arquitetura do Cluster (Control Plane e Workers)

1 Control Plane (Master): Roda a API, Scheduler e armazena o estado do cluster.

2 Worker Nodes: Nós de processamento distribuídos, garantindo capacidade mínima para Alta Disponibilidade (HA) e testes de escalabilidade.

Acesso SSH restrito utilizando chaves criptográficas (ssh_authorized_keys) injetadas no ato do provisionamento via Terraform.

---

## 7. Automação de Bootstrap (Ansible)

Em vez de depender de scripts de inicialização rígidos (cloud-init), o bootstrap do cluster foi orquestrado pelo Ansible (k3s-install.yml), responsável por:

- Atualizar o IP público dinamicamente via requisição externa (CloudNS).
- Desabilitar o firewalld no Oracle Linux para evitar bloqueios de rede do Kubernetes.
- Instalar o K3s Master e extrair de forma segura o token do cluster (/var/lib/rancher/k3s/server/node-token).
- Configurar os Workers injetando a URL do Master e o token extraído.
- Instalar o Helm CLI e adicionar repositórios fundamentais.
- Realizar o deploy automático do Nginx Ingress e do Cert-Manager.
- Aplicar os manifests da aplicação (whoami.yaml, cluster-issuer.yaml, whoami-ingress.yaml).


---

## 8. CI/CD — GitHub Actions

O pipeline terraform-deploy.yml orquestra a execução da infraestrutura.

* Controles de execução e segurança (Apply/Destroy)

- Para evitar mudanças acidentais, os pipelines possuem entradas rigorosas:
- A execução principal é disparada no evento de push na branch main ou de forma manual (workflow_dispatch).
- A etapa de Destroy só é executada se explicitamente selecionada de forma manual.
- Preparação de chaves (OCI API, SSH Privada e Pública) injetadas de forma segura via GitHub Secrets e tratadas para compatibilidade (remoção de \r do Windows).
- Instalação e execução do Terraform e Ansible dinamicamente no runner do Ubuntu.


---

## 9. Ingress Controller

Foi utilizado o ingress-nginx (instalado via Helm através do Ansible).

- Controlador de entrada amplamente adotado e compatível com K3s (substituindo o Traefik padrão).
- Permite o roteamento de HTTP e HTTPS mapeado diretamente para o serviço da aplicação.


---

## 10. Certificados TLS

### Ferramenta: cert-manager

- Emissão automática de certificados TLS via Let’s Encrypt (letsencrypt-prod).
- Secret TLS próprio (whoami-tls-secret) associado dinamicamente ao FQDN exposto.
- Nenhum certificado gerado ou mantido manualmente.

---

## 11. Ingress Controller

Foi utilizado **ingress-nginx** como controlador de entrada pois:

- Amplamente adotado
- Boa documentação
- Integração direta com cert-manager
- Compatível com AKS

Ingress configurado para:
- HTTP e HTTPS
- TLS automático
- Integração com Cloudflare

---

## 12. Certificados TLS

### Ferramenta: cert-manager

- Emissão automática de certificados
- Integração com Let’s Encrypt
- Renovação automática
- Nenhum certificado manual

Cada serviço exposto possui:
- Secret TLS próprio
- Hostname explícito
- Validação ACME funcional

---

## 13. DNS — CloudNS Dinâmico

### Por que Cloudflare?

- Proteção DDoS
- Proxy reverso
- TLS edge
- Controle programático via API
- Integração automatizada

O pipeline:
- Obtém o IP público do Ingress
- Cria ou atualiza registros DNS
- Suporta múltiplos FQDNs (app + grafana)

---

## 14. Observabilidade

### Stack utilizada

- kube-prometheus-stack (Prometheus, Kube-State-Metrics, Node Exporter, Grafana)

*Características:

- Instalação completa garantindo a persistência do Grafana via PVC (Persistent Volume Claim) no disco da Oracle Cloud.
- Importação do Dashboard 1860 (Node Exporter Full) para acompanhamento aprofundado do hardware de todas as máquinas (CPU, RAM, Disco, Rede).
- Acesso administrativo seguro via port-forward na porta 8080, sem exposição direta de portas de gerência na internet.


---

## 15. Logging

### Stack de Logs

- Loki
- Promtail

**Motivo da escolha:**
- Baixo custo operacional
- Integração nativa com Grafana
- Labels baseados em Kubernetes
- Arquitetura simples

Configurações foram ajustadas para:
- Compatibilidade com versão do Loki
- Evitar recursos experimentais desnecessários
- Garantir estabilidade do pod

---

## 17. Segurança

Medidas adotadas:

- Secrets nunca versionados
- Variáveis sensíveis via GitHub Secrets
- ServiceAccounts mínimos
- TLS em todos os serviços expostos
- Nenhum endpoint aberto sem necessidade

---

## 18. Endpoints de Acesso

Após a conclusão do provisionamento da infraestrutura, configuração de Ingress, DNS e certificados TLS, os seguintes endpoints públicos ficaram disponíveis:

### Aplicação

- https://meuprojetok8s.cloud-ip.cc


Endpoint principal da aplicação exposta no cluster Kubernetes.

Características:
- Exposição via Ingress Controller (ingress-nginx)
- DNS gerenciado pelo Cloudflare
- Tráfego HTTPS com TLS automático via cert-manager
- Certificado emitido pelo Let’s Encrypt
- Registro DNS configurado como proxied (orange cloud), garantindo mascaramento do IP de origem

Observabilidade e Logs (Grafana):
- Acesso: Exclusivo via rede interna / túnel seguro (kubectl port-forward).
- Permite correlação total entre as métricas do hardware (Prometheus) e os logs transacionais em tempo real (Loki)

---

### Observação sobre o ambiente

Este ambiente foi construído com foco em demonstração técnica e boas práticas arquiteturais.

Embora utilize padrões próximos aos de produção, alguns parâmetros (como quantidade de nós, limites de escalonamento e retenção de logs) foram ajustados para o contexto de avaliação técnica.


## 19. Resultado Final


### O projeto entrega

- Infraestrutura IaaS (Compute/Rede) automatizada na OCI via Terraform.
- Orquestração completa de um Cluster K3s bare-metal via Ansible.
- Deploy de Ingress Nginx e gestão de certificados ACME com Cert-Manager.
- Atualização dinâmica de DNS integrada na esteira.
- Observabilidade Sênior (Métricas e Logs) com Prometheus, Grafana e Loki totalmente integrados.
- Pipeline CI/CD com fluxos seguros de Apply e Destroy no GitHub Actions.

Tudo desenvolvido com base nas metodologias de GitOps e IaC, comprovando maturidade técnica em arquitetura de infraestruturas resilientes, seguras e modernas.

