<script setup>
import { ref, onMounted, computed } from 'vue'
import { useRouter } from 'vue-router'
import { Filter, Search, Plus } from '@lucide/vue'
import api from '../api'
import { useCondominiumsStore } from '../store/condominiums'
import { storeToRefs } from 'pinia'

const router = useRouter()
const condominiumsStore = useCondominiumsStore()
const { condominiums, isLoading } = storeToRefs(condominiumsStore)

const filters = ref({
  search: '',
  status: '',
  buildingType: '',
  progress: ''
})

const fetchCondominiums = () => {
  condominiumsStore.fetchCondominiums()
}

onMounted(() => {
  fetchCondominiums()
})

const clearFilters = () => {
  filters.value = { search: '', status: '', buildingType: '', progress: '' }
}

const formatDate = (dateString) => {
  if (!dateString) return ''
  return new Date(dateString).toLocaleDateString('pt-BR')
}
</script>

<template>
  <div class="page-container">
    
    <!-- Top Filter Bar -->
    <div class="filter-bar">
      <div class="filter-inputs">
        <div class="input-group search-group">
          <input type="text" v-model="filters.search" placeholder="Nome, construtora ou endereço">
        </div>
        
        <div class="input-group select-group">
          <label>Status</label>
          <select v-model="filters.status">
            <option value="">Selecione</option>
            <option value="Condomínio">Condomínio</option>
            <option value="Lançamento">Lançamento</option>
          </select>
        </div>

        <div class="input-group select-group">
          <label>Tipo</label>
          <select v-model="filters.buildingType">
            <option value="">Selecione</option>
            <option value="Horizontal">Horizontal</option>
            <option value="Vertical">Vertical</option>
            <option value="Loteamento">Loteamento</option>
          </select>
        </div>

        <div class="input-group select-group">
          <label>Progresso da Obra</label>
          <select v-model="filters.progress">
            <option value="">Selecione</option>
            <option value="Não iniciado">Não iniciado</option>
            <option value="Pronto para morar">Pronto para morar</option>
            <option value="Em construção">Em construção</option>
            <option value="Lançamento">Lançamento</option>
            <option value="Últimas unidades">Últimas unidades</option>
            <option value="Não informado">Não informado</option>
          </select>
        </div>
      </div>
      
      <div class="filter-actions">
        <div class="left-actions">
          <button class="btn-advanced-filter">
            <Filter class="icon-sm" /> Filtro avançado
            <span class="badge">0</span>
          </button>
          <span class="total-text">Total: {{ condominiums.length }}</span>
        </div>
        
        <div class="right-actions">
          <button class="btn-clear" @click="clearFilters">Limpar</button>
          <button class="btn-search"><Search class="icon-sm" /> Buscar</button>
        </div>
      </div>
    </div>

    <!-- Table List -->
    <div class="table-container">
      <table class="data-table">
        <thead>
          <tr>
            <th>STATUS</th>
            <th>TIPO</th>
            <th>NOME</th>
            <th>INCORPORADORA</th>
            <th>CONSTRUTORA</th>
            <th>BAIRRO/CIDADE</th>
            <th>ENTREGA</th>
          </tr>
        </thead>
        <tbody>
          <template v-if="isLoading">
            <tr v-for="i in 3" :key="'skel'+i" class="skeleton-row">
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line short"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line"></div></td>
              <td><div class="skeleton-line short"></div></td>
            </tr>
          </template>
          <tr v-else-if="condominiums.length === 0">
            <td colspan="7" class="text-center py-4 text-muted">Nenhum condomínio encontrado.</td>
          </tr>
          <tr v-for="condominium in condominiums" :key="condominium.id">
            <td>{{ condominium.status || '-' }}</td>
            <td>{{ condominium.buildingType ? `${condominium.buildingType}: ${condominium.subType || ''}` : '-' }}</td>
            <td class="font-medium">{{ condominium.name }}</td>
            <td>{{ condominium.developer || '-' }}</td>
            <td>{{ condominium.builder || '-' }}</td>
            <td>
              <span v-if="condominium.neighborhood || condominium.city">
                {{ condominium.neighborhood }}{{ condominium.neighborhood && condominium.city ? '/' : '' }}{{ condominium.city }}
              </span>
              <span v-else>-</span>
            </td>
            <td>{{ formatDate(condominium.delivery_date) || '-' }}</td>
          </tr>
        </tbody>
      </table>
    </div>

    <!-- Floating Action Button -->
    <button class="fab" title="Adicionar Condomínio" @click="router.push('/condominios/novo')">
      <Plus class="icon-lg" />
    </button>
    
  </div>
</template>

<style lang="scss" scoped>
.page-container {
  padding: 2rem;
  background: var(--bg-primary);
  height: 100%;
  overflow-y: auto;
  position: relative;
}

/* Filter Bar */
.filter-bar {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  padding: 1.5rem;
  margin-bottom: 2rem;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);

  .filter-inputs {
    display: grid;
    grid-template-columns: 2fr 1fr 1fr 1fr;
    gap: 1rem;
    margin-bottom: 1.5rem;

    .input-group {
      position: relative;
      
      &.select-group label {
        position: absolute;
        top: -8px;
        left: 10px;
        background: var(--bg-secondary);
        padding: 0 4px;
        font-size: 0.75rem;
        color: #4338ca;
        z-index: 1;
      }

      input, select {
        width: 100%;
        padding: 0.75rem 1rem;
        border: 1px solid var(--border-color);
        border-radius: 6px;
        background: var(--bg-primary);
        color: var(--text-main);
        font-size: 0.9rem;
        outline: none;
        appearance: none;
        
        &:focus {
          border-color: #4338ca;
        }
      }
      
      select {
        background-image: url("data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' width='16' height='16' viewBox='0 0 24 24' fill='none' stroke='%234338ca' stroke-width='2' stroke-linecap='round' stroke-linejoin='round'%3E%3Cpolyline points='6 9 12 15 18 9'%3E%3C/polyline%3E%3C/svg%3E");
        background-repeat: no-repeat;
        background-position: right 1rem center;
        padding-right: 2.5rem;
      }
    }
  }

  .filter-actions {
    display: flex;
    justify-content: space-between;
    align-items: center;

    .left-actions {
      display: flex;
      align-items: center;
      gap: 1rem;

      .btn-advanced-filter {
        display: flex;
        align-items: center;
        gap: 0.5rem;
        background: transparent;
        border: 1px solid var(--border-color);
        padding: 0.5rem 1rem;
        border-radius: 6px;
        color: var(--text-main);
        font-weight: 500;
        cursor: pointer;
        position: relative;

        .badge {
          position: absolute;
          top: -8px;
          right: -8px;
          background: #4338ca;
          color: white;
          font-size: 0.7rem;
          width: 18px;
          height: 18px;
          border-radius: 50%;
          display: flex;
          align-items: center;
          justify-content: center;
        }
      }

      .total-text {
        font-weight: 600;
        color: #4338ca;
        font-size: 0.9rem;
      }
    }

    .right-actions {
      display: flex;
      gap: 1rem;

      button {
        padding: 0.6rem 2rem;
        border-radius: 20px;
        font-weight: 500;
        cursor: pointer;
        display: flex;
        align-items: center;
        gap: 0.5rem;
        
        &.btn-clear {
          background: transparent;
          border: 1px solid var(--border-color);
          color: var(--text-main);
        }

        &.btn-search {
          background: transparent;
          border: 1px solid #4338ca;
          color: #4338ca;
        }
      }
    }
  }
}

/* Table List */
.table-container {
  background: var(--bg-secondary);
  border: 1px solid var(--border-color);
  border-radius: 8px;
  overflow: hidden;
  box-shadow: 0 1px 3px rgba(0,0,0,0.05);
}

.data-table {
  width: 100%;
  border-collapse: collapse;

  th {
    background: var(--bg-primary);
    color: #4338ca;
    font-weight: 700;
    font-size: 0.8rem;
    text-transform: uppercase;
    text-align: left;
    padding: 1rem;
    border-bottom: 2px solid var(--border-color);
  }

  td {
    padding: 1rem;
    border-bottom: 1px solid var(--border-color);
    color: var(--text-main);
    font-size: 0.9rem;
    
    &.font-medium {
      font-weight: 500;
    }
  }

  tr:last-child td {
    border-bottom: none;
  }
}

.text-center { text-align: center; }
.py-4 { padding-top: 1rem; padding-bottom: 1rem; }
.text-muted { color: var(--text-muted); }
.icon-sm { width: 16px; height: 16px; }

/* Skeleton Loader */
.skeleton-row {
  animation: pulse-skeleton 1.5s infinite;
  
  .skeleton-line {
    height: 12px;
    background: #e5e7eb;
    border-radius: 4px;
    width: 120px;
    
    &.short { width: 60px; }
  }
}

@keyframes pulse-skeleton {
  0% { opacity: 0.6; }
  50% { opacity: 1; }
  100% { opacity: 0.6; }
}

.fab {
  position: fixed;
  bottom: 2rem;
  right: 2rem;
  width: 60px;
  height: 60px;
  border-radius: 50%;
  background: #4338ca;
  color: white;
  border: none;
  display: flex;
  align-items: center;
  justify-content: center;
  cursor: pointer;
  box-shadow: 0 4px 12px rgba(67, 56, 202, 0.4);
  transition: transform 0.2s;
  
  &:hover {
    transform: scale(1.05);
  }
  
  .icon-lg {
    width: 24px;
    height: 24px;
  }
}
</style>
