#!/bin/bash

# ============================================================================
# FlatTrash - Script de Limpeza Completa do Sistema Linux
# Versão: 2.0
# Autor: João M J Braga
# GitHub: https://github.com/joaomjbraga
# Descrição: Remove pacotes desnecessários, caches e libera espaço em disco
# ============================================================================

# Cores para melhor visualização
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # Sem cor

# Função para exibir cabeçalhos
print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

# Função para exibir mensagens de sucesso
print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

# Função para exibir mensagens de aviso
print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

# Função para exibir mensagens de erro
print_error() {
    echo -e "${RED}✗${NC} $1"
}

# Função para exibir informações
print_info() {
    echo -e "${PURPLE}ℹ${NC} $1"
}

# Função para calcular espaço liberado
calculate_space() {
    df -h / | awk 'NR==2 {print $4}'
}

# Verificar se é root
if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root (use sudo)"
    exit 1
fi

# Banner inicial
clear
echo -e "${CYAN}"
cat << "EOF"
╔═══════════════════════════════════════════════════════════════╗
║                                                               ║
║   ███████╗██╗      █████╗ ████████╗████████╗██████╗  █████╗  ║
║   ██╔════╝██║     ██╔══██╗╚══██╔══╝╚══██╔══╝██╔══██╗██╔══██╗ ║
║   █████╗  ██║     ███████║   ██║      ██║   ██████╔╝███████║ ║
║   ██╔══╝  ██║     ██╔══██║   ██║      ██║   ██╔══██╗██╔══██║ ║
║   ██║     ███████╗██║  ██║   ██║      ██║   ██║  ██║██║  ██║ ║
║   ╚═╝     ╚══════╝╚═╝  ╚═╝   ╚═╝      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝ ║
║                                                               ║
║   ████████╗██████╗  █████╗ ███████╗██╗  ██╗                  ║
║   ╚══██╔══╝██╔══██╗██╔══██╗██╔════╝██║  ██║                  ║
║      ██║   ██████╔╝███████║███████╗███████║                  ║
║      ██║   ██╔══██╗██╔══██║╚════██║██╔══██║                  ║
║      ██║   ██║  ██║██║  ██║███████║██║  ██║                  ║
║      ╚═╝   ╚═╝  ╚═╝╚═╝  ╚═╝╚══════╝╚═╝  ╚═╝                  ║
║                                                               ║
║            SCRIPT DE LIMPEZA E OTIMIZAÇÃO v2.0               ║
║                                                               ║
║                  Autor: João M J Braga                        ║
║          GitHub: github.com/joaomjbraga                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

# Capturar espaço antes da limpeza
SPACE_BEFORE=$(calculate_space)
print_info "Espaço livre antes da limpeza: ${GREEN}${SPACE_BEFORE}${NC}"
sleep 2

# ============================================================================
# 1. ATUALIZAÇÃO DE LISTA DE PACOTES
# ============================================================================
print_header "1/9 - Atualizando lista de pacotes"
if apt update -y > /dev/null 2>&1; then
    print_success "Lista de pacotes atualizada"
else
    print_error "Falha ao atualizar lista de pacotes"
fi

# ============================================================================
# 2. REMOÇÃO DE DEPENDÊNCIAS NÃO USADAS
# ============================================================================
print_header "2/9 - Removendo pacotes e dependências não usadas"
REMOVABLE=$(apt autoremove --dry-run | grep -Po '^\d+(?= a remover)' || echo "0")
if [ "$REMOVABLE" -gt 0 ]; then
    print_info "Encontrados ${YELLOW}${REMOVABLE}${NC} pacotes para remover"
    apt autoremove --purge -y > /dev/null 2>&1
    print_success "Pacotes desnecessários removidos"
else
    print_success "Nenhum pacote desnecessário encontrado"
fi

# ============================================================================
# 3. LIMPEZA DE CACHE DO APT
# ============================================================================
print_header "3/9 - Limpando cache do APT"
CACHE_SIZE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1)
print_info "Tamanho do cache atual: ${YELLOW}${CACHE_SIZE}${NC}"
apt clean > /dev/null 2>&1
apt autoclean > /dev/null 2>&1
print_success "Cache do APT limpo"

# ============================================================================
# 4. INSTALAÇÃO E USO DO DEBORPHAN
# ============================================================================
print_header "4/9 - Verificando pacotes órfãos"
if ! command -v deborphan &> /dev/null; then
    print_warning "Instalando deborphan..."
    apt install deborphan -y > /dev/null 2>&1
    print_success "Deborphan instalado"
fi

ORPHANS=$(deborphan | wc -l)
if [ "$ORPHANS" -gt 0 ]; then
    print_info "Encontrados ${YELLOW}${ORPHANS}${NC} pacotes órfãos"
    deborphan | xargs -r apt purge --auto-remove -y > /dev/null 2>&1
    print_success "Pacotes órfãos removidos"
else
    print_success "Nenhum pacote órfão encontrado"
fi

# ============================================================================
# 5. REMOÇÃO DE CONFIGURAÇÕES RESIDUAIS
# ============================================================================
print_header "5/9 - Limpando configurações residuais"
RESIDUAL=$(dpkg -l | grep '^rc' | wc -l)
if [ "$RESIDUAL" -gt 0 ]; then
    print_info "Encontradas ${YELLOW}${RESIDUAL}${NC} configurações residuais"
    dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r apt purge -y > /dev/null 2>&1
    print_success "Configurações residuais removidas"
else
    print_success "Nenhuma configuração residual encontrada"
fi

# ============================================================================
# 6. LIMPEZA DO FLATPAK
# ============================================================================
print_header "6/9 - Verificando Flatpak"
if command -v flatpak &> /dev/null; then
    print_info "Limpando pacotes não utilizados do Flatpak..."
    flatpak uninstall --unused -y > /dev/null 2>&1
    flatpak repair --user > /dev/null 2>&1
    flatpak repair > /dev/null 2>&1
    print_success "Flatpak limpo e reparado"
else
    print_warning "Flatpak não instalado (ignorado)"
fi

# ============================================================================
# 7. LIMPEZA DE LOGS DO SISTEMA
# ============================================================================
print_header "7/9 - Limpando logs antigos"
JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[GM]' | head -1)
print_info "Tamanho dos logs: ${YELLOW}${JOURNAL_SIZE}${NC}"
journalctl --vacuum-time=7d > /dev/null 2>&1
print_success "Logs com mais de 7 dias removidos"

# ============================================================================
# 8. LIMPEZA DE CACHES DO USUÁRIO
# ============================================================================
print_header "8/9 - Limpando caches do usuário"
if [ -d "$HOME/.cache" ]; then
    CACHE_USER_SIZE=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1)
    print_info "Tamanho do cache do usuário: ${YELLOW}${CACHE_USER_SIZE}${NC}"
    rm -rf "$HOME/.cache"/*
    print_success "Cache do usuário limpo"
fi

# Limpar cache de thumbnails
if [ -d "$HOME/.thumbnails" ]; then
    rm -rf "$HOME/.thumbnails"/*
    print_success "Miniaturas removidas"
fi

# ============================================================================
# 9. LIMPEZA DE CACHES DO SISTEMA
# ============================================================================
print_header "9/9 - Limpando caches do sistema"
rm -rf /var/cache/apt/archives/* > /dev/null 2>&1
rm -rf /tmp/* > /dev/null 2>&1
print_success "Caches do sistema limpos"

# ============================================================================
# RELATÓRIO FINAL
# ============================================================================
SPACE_AFTER=$(calculate_space)
print_header "LIMPEZA CONCLUÍDA COM SUCESSO"

echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                   ${GREEN}RELATÓRIO FINAL${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Espaço livre antes:  ${YELLOW}${SPACE_BEFORE}${NC}"
echo -e "${CYAN}║${NC} Espaço livre agora:  ${GREEN}${SPACE_AFTER}${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

print_success "Sistema otimizado e limpo!"
print_info "Recomenda-se reiniciar o sistema para aplicar todas as mudanças"

# Perguntar se deseja reiniciar
read -p "$(echo -e ${YELLOW}Deseja reiniciar o sistema agora? [s/N]:${NC} )" -n 1 -r
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    print_info "Reiniciando em 5 segundos..."
    sleep 5
    reboot
else
    print_info "Você pode reiniciar manualmente mais tarde"
fi