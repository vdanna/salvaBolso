# Salva Bolso — Pendências para Produção

## 1. Objetivo

Este documento registra configurações e melhorias de segurança
identificadas durante o desenvolvimento do Salva Bolso.

O projeto foi concebido para execução self-hosted, permitindo
que os usuários hospedem o aplicativo e seu backend em
infraestrutura própria.

As configurações atuais priorizam a facilidade de desenvolvimento
e a execução em ambientes controlados.

As recomendações abaixo deverão ser avaliadas antes de uma
implantação que processe dados financeiros reais, especialmente
quando houver acesso pela internet ou por redes não confiáveis.

---

## 2. Configurações de segurança

### 2.1. Credenciais do PostgreSQL

Arquivos envolvidos:
- backend/.env.example
- backend/app/core/config.py
- backend/docker-compose.yaml

Situação atual:
- Existem credenciais demonstrativas.
- O Docker Compose permite utilizar uma senha padrão.

Recomendação:
- Exigir senha específica para cada instalação.
- Remover credenciais previsíveis utilizadas como fallback.
- Impedir a inicialização com credenciais demonstrativas.

Status: PENDENTE

### 2.2. Segurança dos tokens JWT

Arquivos envolvidos:
- backend/.env.example
- backend/app/core/config.py

Situação atual:
- Existem chaves demonstrativas utilizadas como padrão.

Recomendação:
- Exigir JWT_SECRET_KEY segura.
- Impedir inicialização com chaves demonstrativas.
- Definir procedimento de geração e armazenamento da chave.
- Avaliar políticas de expiração e renovação de tokens.

Status: PENDENTE

### 2.3. Modo de depuração

Arquivos envolvidos:
- backend/.env.example
- backend/app/core/config.py

Situação atual:
- DEBUG habilitado por padrão.

Recomendação:
- Desabilitar DEBUG nas instalações de produção.
- Manter depuração habilitada somente em desenvolvimento.
- Revisar informações sensíveis presentes nos logs.

Status: PENDENTE

---

## 3. Configuração de rede

### 3.1. PostgreSQL

Arquivo envolvido:
- backend/docker-compose.yaml

Situação atual:
- A porta do PostgreSQL pode ser publicada nas interfaces
  de rede do host.

Recomendação:
- Evitar exposição pública da porta 5432.
- Utilizar rede interna do Docker quando possível.
- Permitir acesso externo apenas quando necessário e protegido.

Status: PENDENTE

### 3.2. API FastAPI

Recomendações:
- Utilizar HTTPS quando houver acesso pela rede.
- Configurar adequadamente as origens permitidas pelo CORS.
- Avaliar utilização de proxy reverso.
- Documentar as portas necessárias para instalação self-hosted.

Status: PENDENTE

---

## 4. Segurança do Docker

Arquivo envolvido:
- backend/Dockerfile

Recomendações:
- Executar a aplicação com usuário não privilegiado.
- Revisar atualizações das imagens-base.
- Evitar inclusão de arquivos sensíveis nas imagens.
- Avaliar permissões dos volumes persistentes.

Status: PENDENTE

---

## 5. Integridade e recuperação dos dados

Recomendações:
- Documentar backup do PostgreSQL.
- Implementar procedimento de restauração.
- Testar periodicamente a recuperação dos dados.
- Definir procedimentos de atualização do banco com Alembic.
- Garantir persistência dos dados entre atualizações.

Status: PENDENTE

---

## 6. Distribuição self-hosted

Recomendações:
- Criar documentação de instalação.
- Disponibilizar modelo seguro de variáveis de ambiente.
- Documentar os requisitos mínimos de infraestrutura.
- Estabelecer procedimento de atualização.
- Documentar mecanismos de backup e recuperação.

Status: PENDENTE

---

## 7. Observações

Este documento não indica que todas as recomendações
precisam ser implementadas durante o desenvolvimento inicial.

Entretanto, configurações demonstrativas não deverão
ser utilizadas em instalações que processem dados reais.

As alterações deverão ser implementadas gradualmente,
com testes para preservar a compatibilidade das
funcionalidades existentes.

Nenhuma credencial real deve ser registrada neste documento.
