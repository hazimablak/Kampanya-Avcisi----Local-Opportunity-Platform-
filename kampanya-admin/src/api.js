import axios from 'axios';

const api = axios.create({
  baseURL: 'http://localhost:3000' // Backend'in çalıştığı port
});

// BİLETİ OTOMATİK TAKMA AJANI (INTERCEPTOR)
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('adminToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export default api;