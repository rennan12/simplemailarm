# Estágio 1: Node (Mantendo compatibilidade)
FROM node:10.17.0-alpine AS npm
WORKDIR /code
COPY ./static/package*.json /code/static/
RUN cd /code/static && npm ci

# Estágio 2: Ubuntu (Nativo para seu servidor ARM)
FROM ubuntu:22.04

ARG UV_VERSION="0.7.13"

# Configurações do Python
ENV PYTHONDONTWRITEBYTECODE=1
ENV PYTHONUNBUFFERED=1

WORKDIR /code

# Copia arquivos de dependência
COPY pyproject.toml uv.lock .python-version ./

# Instalação corrigida para ARM (Aarch64)
# Note que corrigi os comandos 'mv' abaixo para procurar a pasta 'aarch64'
RUN apt-get update \
    && apt-get install -y curl netcat-traditional gcc python3-dev gnupg git libre2-dev build-essential pkg-config cmake ninja-build bash clang \
    && curl -sSL "https://github.com/astral-sh/uv/releases/download/${UV_VERSION}/uv-aarch64-unknown-linux-gnu.tar.gz" > uv.tar.gz \
    && tar xf uv.tar.gz -C /tmp/ \
    && mv /tmp/uv-aarch64-unknown-linux-gnu/uv /usr/bin/uv \
    && mv /tmp/uv-aarch64-unknown-linux-gnu/uvx /usr/bin/uvx \
    && rm -rf /tmp/uv* \
    && rm -f uv.tar.gz \
    && uv python install `cat .python-version` \
    && export CMAKE_POLICY_VERSION_MINIMUM=3.5 \
    && uv sync --locked \
    && apt-get autoremove -y \
    && apt-get purge -y curl netcat-traditional build-essential pkg-config cmake ninja-build python3-dev clang \
    && apt-get autoremove -y \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Copia o código da aplicação
COPY . .

# Copia os pacotes do Node do primeiro estágio
COPY --from=npm /code /code

ENV PATH="/code/.venv/bin:$PATH"
EXPOSE 7777

CMD ["gunicorn", "wsgi:app", "-b", "0.0.0.0:7777", "-w", "2", "--timeout", "15", "--log-level", "DEBUG"]
