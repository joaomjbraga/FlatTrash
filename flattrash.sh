#!/bin/bash

# ============================================================================
# FlatTrash - Script de Limpeza Completa do Sistema Linux
# Versão: 2.1
# Autor: João M J Braga
# GitHub: https://github.com/joaomjbraga
# Descrição: Remove pacotes desnecessários, caches e libera espaço em disco
# ============================================================================

set -euo pipefail  # Melhor tratamento de erros

# Cores para melhor visualização
readonly RED='\033[0;31m'
readonly GREEN='\033[0;32m'
readonly YELLOW='\033[1;33m'
readonly BLUE='\033[0;34m'
readonly PURPLE='\033[0;35m'
readonly CYAN='\033[0;36m'
readonly NC='\033[0m'

# Variáveis globais
SPACE_BEFORE=""
SPACE_AFTER=""
TOTAL_FREED=0
LOG_FILE="/var/log/flattrash_$(date +%Y%m%d_%H%M%S).log"

# ============================================================================
# FUNÇÕES DE EXIBIÇÃO
# ============================================================================

print_header() {
    echo -e "\n${CYAN}╔════════════════════════════════════════════════════════════╗${NC}"
    echo -e "${CYAN}║${NC} ${BLUE}$1${NC}"
    echo -e "${CYAN}╚════════════════════════════════════════════════════════════╝${NC}"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] SUCCESS: $1" >> "$LOG_FILE"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] WARNING: $1" >> "$LOG_FILE"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
    echo "[$(date '+%Y-%m-%d %H:%M:%S')] ERROR: $1" >> "$LOG_FILE"
}

print_info() {
    echo -e "${PURPLE}ℹ${NC} $1"
}

# ============================================================================
# FUNÇÕES AUXILIARES
# ============================================================================

calculate_space() {
    df -BG / | awk 'NR==2 {print $4}' | sed 's/G//'
}

calculate_space_human() {
    df -h / | awk 'NR==2 {print $4}'
}

check_command() {
    command -v "$1" &> /dev/null
}

safe_remove() {
    local path="$1"
    if [ -d "$path" ] || [ -f "$path" ]; then
        rm -rf "$path" 2>/dev/null || print_warning "Não foi possível remover: $path"
    fi
}

# Criar backup de segurança
create_backup_point() {
    print_info "Criando ponto de restauração..."
    dpkg --get-selections > /var/backups/flattrash_packages_backup_$(date +%Y%m%d).txt 2>/dev/null || true
}

# ============================================================================
# VERIFICAÇÕES INICIAIS
# ============================================================================

if [ "$EUID" -ne 0 ]; then
    print_error "Este script precisa ser executado como root (use sudo)"
    exit 1
fi

# Verificar conexão com internet
if ! ping -c 1 8.8.8.8 &> /dev/null; then
    print_warning "Sem conexão com a internet. Algumas operações podem falhar."
    read -p "Deseja continuar? [s/N]: " -n 1 -r
    echo
    [[ ! $REPLY =~ ^[SsYy]$ ]] && exit 0
fi

# ============================================================================
# BANNER INICIAL
# ============================================================================

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
║            SCRIPT DE LIMPEZA E OTIMIZAÇÃO v2.1               ║
║                                                               ║
║                  Autor: João M J Braga                        ║
║          GitHub: github.com/joaomjbraga                       ║
╚═══════════════════════════════════════════════════════════════╝
EOF
echo -e "${NC}"

print_info "Log será salvo em: ${YELLOW}${LOG_FILE}${NC}"
SPACE_BEFORE=$(calculate_space)
print_info "Espaço livre antes da limpeza: ${GREEN}$(calculate_space_human)${NC}"
sleep 2

create_backup_point

# ============================================================================
# 1. ATUALIZAÇÃO DE LISTA DE PACOTES
# ============================================================================
print_header "1/10 - Atualizando lista de pacotes"
if apt update -y 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
    print_success "Lista de pacotes atualizada"
else
    print_error "Falha ao atualizar lista de pacotes"
fi

# ============================================================================
# 2. REMOÇÃO DE DEPENDÊNCIAS NÃO USADAS
# ============================================================================
print_header "2/10 - Removendo pacotes e dependências não usadas"
REMOVABLE=$(apt autoremove --dry-run 2>/dev/null | grep -Po '^\d+(?= (a remover|to remove))' || echo "0")
if [ "$REMOVABLE" -gt 0 ]; then
    print_info "Encontrados ${YELLOW}${REMOVABLE}${NC} pacotes para remover"
    if apt autoremove --purge -y 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
        print_success "Pacotes desnecessários removidos"
    else
        print_warning "Alguns pacotes não puderam ser removidos"
    fi
else
    print_success "Nenhum pacote desnecessário encontrado"
fi

# ============================================================================
# 3. LIMPEZA DE CACHE DO APT
# ============================================================================
print_header "3/10 - Limpando cache do APT"
if [ -d /var/cache/apt/archives ]; then
    CACHE_SIZE=$(du -sh /var/cache/apt/archives 2>/dev/null | cut -f1 || echo "0")
    print_info "Tamanho do cache atual: ${YELLOW}${CACHE_SIZE}${NC}"
    apt clean 2>&1 | tee -a "$LOG_FILE" > /dev/null
    apt autoclean 2>&1 | tee -a "$LOG_FILE" > /dev/null
    print_success "Cache do APT limpo"
else
    print_warning "Diretório de cache não encontrado"
fi

# ============================================================================
# 4. INSTALAÇÃO E USO DO DEBORPHAN
# ============================================================================
print_header "4/10 - Verificando pacotes órfãos"
if ! check_command deborphan; then
    print_warning "Instalando deborphan..."
    if apt install deborphan -y 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
        print_success "Deborphan instalado"
    else
        print_error "Falha ao instalar deborphan"
    fi
fi

if check_command deborphan; then
    ORPHANS=$(deborphan 2>/dev/null | wc -l)
    if [ "$ORPHANS" -gt 0 ]; then
        print_info "Encontrados ${YELLOW}${ORPHANS}${NC} pacotes órfãos"
        if deborphan | xargs -r apt purge --auto-remove -y 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
            print_success "Pacotes órfãos removidos"
        else
            print_warning "Alguns pacotes órfãos não puderam ser removidos"
        fi
    else
        print_success "Nenhum pacote órfão encontrado"
    fi
fi

# ============================================================================
# 5. REMOÇÃO DE CONFIGURAÇÕES RESIDUAIS
# ============================================================================
print_header "5/10 - Limpando configurações residuais"
RESIDUAL=$(dpkg -l 2>/dev/null | grep '^rc' | wc -l)
if [ "$RESIDUAL" -gt 0 ]; then
    print_info "Encontradas ${YELLOW}${RESIDUAL}${NC} configurações residuais"
    if dpkg -l | grep '^rc' | awk '{print $2}' | xargs -r apt purge -y 2>&1 | tee -a "$LOG_FILE" > /dev/null; then
        print_success "Configurações residuais removidas"
    else
        print_warning "Algumas configurações não puderam ser removidas"
    fi
else
    print_success "Nenhuma configuração residual encontrada"
fi

# ============================================================================
# 6. LIMPEZA DO FLATPAK
# ============================================================================
print_header "6/10 - Verificando Flatpak"
if check_command flatpak; then
    print_info "Limpando pacotes não utilizados do Flatpak..."
    flatpak uninstall --unused -y 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    flatpak repair --user 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    flatpak repair 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    print_success "Flatpak limpo e reparado"
else
    print_warning "Flatpak não instalado (ignorado)"
fi

# ============================================================================
# 7. LIMPEZA DO SNAP
# ============================================================================
print_header "7/10 - Verificando Snap"
if check_command snap; then
    print_info "Removendo versões antigas de snaps..."
    snap list --all | awk '/disabled/{print $1, $3}' | while read snapname revision; do
        snap remove "$snapname" --revision="$revision" 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    done
    print_success "Snaps otimizados"
else
    print_warning "Snap não instalado (ignorado)"
fi

# ============================================================================
# 8. LIMPEZA DE LOGS DO SISTEMA
# ============================================================================
print_header "8/10 - Limpando logs antigos"
if check_command journalctl; then
    JOURNAL_SIZE=$(journalctl --disk-usage 2>/dev/null | grep -oP '\d+\.\d+[KMGT]B?' | head -1 || echo "0")
    print_info "Tamanho dos logs: ${YELLOW}${JOURNAL_SIZE}${NC}"
    journalctl --vacuum-time=7d 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    journalctl --vacuum-size=100M 2>&1 | tee -a "$LOG_FILE" > /dev/null || true
    print_success "Logs otimizados (mantidos últimos 7 dias ou máx 100MB)"
else
    print_warning "journalctl não disponível"
fi

# Limpar logs antigos em /var/log
find /var/log -type f -name "*.log.*" -mtime +7 -delete 2>/dev/null || true
find /var/log -type f -name "*.gz" -mtime +7 -delete 2>/dev/null || true
print_success "Logs compactados antigos removidos"

# ============================================================================
# 9. LIMPEZA DE CACHES DO USUÁRIO
# ============================================================================
print_header "9/10 - Limpando caches do usuário"

# Cache do usuário root
if [ -d "$HOME/.cache" ]; then
    CACHE_USER_SIZE=$(du -sh "$HOME/.cache" 2>/dev/null | cut -f1 || echo "0")
    print_info "Tamanho do cache do usuário root: ${YELLOW}${CACHE_USER_SIZE}${NC}"
    find "$HOME/.cache" -type f -atime +30 -delete 2>/dev/null || true
    print_success "Cache antigo do usuário root limpo"
fi

# Limpar cache de thumbnails
safe_remove "$HOME/.thumbnails/*"
print_success "Miniaturas do root removidas"

# Limpar caches de outros usuários (se executado como root)
for user_home in /home/*; do
    if [ -d "$user_home/.cache" ]; then
        username=$(basename "$user_home")
        CACHE_SIZE=$(du -sh "$user_home/.cache" 2>/dev/null | cut -f1 || echo "0")
        print_info "Limpando cache de ${username}: ${YELLOW}${CACHE_SIZE}${NC}"
        find "$user_home/.cache" -type f -atime +30 -delete 2>/dev/null || true
        safe_remove "$user_home/.thumbnails/*"
    fi
done
print_success "Caches de usuários limpos"

# ============================================================================
# 10. LIMPEZA DE CACHES DO SISTEMA
# ============================================================================
print_header "10/10 - Limpando caches do sistema"

# Limpar cache do APT
safe_remove "/var/cache/apt/archives/*.deb"
safe_remove "/var/cache/apt/archives/partial/*"

# Limpar temp files (mais seguro)
find /tmp -type f -atime +2 -delete 2>/dev/null || true
find /var/tmp -type f -atime +7 -delete 2>/dev/null || true

# Limpar cache do Python pip
safe_remove "/root/.cache/pip/*"
for user_home in /home/*; do
    safe_remove "$user_home/.cache/pip/*"
done

# Limpar cache do npm (se existir)
if [ -d "/root/.npm" ]; then
    npm cache clean --force 2>/dev/null || true
fi

print_success "Caches do sistema limpos"

# ============================================================================
# OTIMIZAÇÕES ADICIONAIS
# ============================================================================
print_header "Otimizações Finais"

# Limpar cores antigas do man
safe_remove "/var/cache/man/*"
print_success "Cache do man limpo"

# Atualizar locate database
if check_command updatedb; then
    updatedb 2>/dev/null || true
    print_success "Database do locate atualizada"
fi

# ============================================================================
# RELATÓRIO FINAL
# ============================================================================
SPACE_AFTER=$(calculate_space)
TOTAL_FREED=$((SPACE_BEFORE - SPACE_AFTER))

print_header "LIMPEZA CONCLUÍDA COM SUCESSO"

echo -e "\n${CYAN}╔═══════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║${NC}                   ${GREEN}RELATÓRIO FINAL${NC}                      ${CYAN}║${NC}"
echo -e "${CYAN}╠═══════════════════════════════════════════════════════════╣${NC}"
echo -e "${CYAN}║${NC} Espaço livre antes:  ${YELLOW}$(calculate_space_human)${NC} (${SPACE_BEFORE}GB)"
echo -e "${CYAN}║${NC} Espaço livre agora:  ${GREEN}$(calculate_space_human)${NC} (${SPACE_AFTER}GB)"
if [ "$TOTAL_FREED" -gt 0 ]; then
    echo -e "${CYAN}║${NC} Espaço liberado:    ${GREEN}${TOTAL_FREED}GB${NC}"
fi
echo -e "${CYAN}║${NC}"
echo -e "${CYAN}║${NC} Log completo salvo em:"
echo -e "${CYAN}║${NC} ${YELLOW}${LOG_FILE}${NC}"
echo -e "${CYAN}╚═══════════════════════════════════════════════════════════╝${NC}\n"

print_success "Sistema otimizado e limpo!"
print_info "Recomenda-se reiniciar o sistema para aplicar todas as mudanças"

# Perguntar se deseja reiniciar
echo -e "${YELLOW}Deseja reiniciar o sistema agora? [s/N]:${NC} \c"
read -r -n 1 REPLY
echo
if [[ $REPLY =~ ^[SsYy]$ ]]; then
    print_info "Reiniciando em 5 segundos... (Ctrl+C para cancelar)"
    sleep 5
    reboot
else
    print_info "Você pode reiniciar manualmente mais tarde com: sudo reboot"
fi

exit 0