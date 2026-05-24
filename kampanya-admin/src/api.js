import axios from 'axios';

// Node.js backend'imizin adresi
const api = axios.create({
  baseURL: 'http://localhost:3000', 
});

// GÜVENLİK GÖREVLİSİ: Her istekten önce çalışır ve cebimizdeki bileti (Token) gösterir
api.interceptors.request.use((config) => {
  const token = localStorage.getItem('adminToken');
  if (token) {
    config.headers.Authorization = `Bearer ${token}`;
  }
  return config;
});

export default api;