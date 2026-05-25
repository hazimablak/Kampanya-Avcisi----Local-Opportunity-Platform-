import axios from 'axios';

const api = axios.create({
  baseURL: 'https://kampanya-avcisi-api.onrender.com' // Backend'in çalıştığı port
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