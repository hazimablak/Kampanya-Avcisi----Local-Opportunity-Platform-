import React, { useState } from 'react';
import api from './api';

export default function Login({ onLoginSuccess }) {
  const [phone, setPhone] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [isLoading, setIsLoading] = useState(false);
  
  // 1. YENİ DURUM: Şifre görünür mü, gizli mi?
  const [showPassword, setShowPassword] = useState(false);

  const handleLogin = async (e) => {
    e.preventDefault();
    setError('');
    setIsLoading(true);

    try {
      const response = await api.post('/api/login', { phone, password });
      
      if (response.status === 200) {
        if (!response.data.isAdmin) {
          setError('Yetkisiz Giriş! Bu panele sadece Sistem Yöneticisi girebilir.');
          setIsLoading(false);
          return;
        }

        localStorage.setItem('adminToken', response.data.accessToken);
        onLoginSuccess();
      }
    } catch (err) {
      setError('Giriş başarısız! Numara veya şifre hatalı.');
    } finally {
      setIsLoading(false);
    }
  };

  return (
    <div style={styles.container}>
      <div style={styles.card}>
        <div style={styles.header}>
          <h1 style={styles.title}>Kampanya Avcısı</h1>
          <p style={styles.subtitle}>Sistem Yönetim Paneli</p>
        </div>

        {error && <div style={styles.error}>{error}</div>}

        <form onSubmit={handleLogin} style={styles.form}>
          <div style={styles.inputGroup}>
            <label style={styles.label}>Admin Telefon Numarası</label>
            <input 
              type="text" 
              value={phone} 
              onChange={(e) => setPhone(e.target.value)} 
              style={styles.input} 
              placeholder="Örn: 05551234567"
              required 
            />
          </div>

          <div style={styles.inputGroup}>
            <label style={styles.label}>Admin Şifresi</label>
            {/* 2. ŞİFRE KUTUSUNU YENİDEN DÜZENLEDİK */}
            <div style={{ display: 'flex', position: 'relative' }}>
              <input 
                type={showPassword ? "text" : "password"} // Göz açıksa text, kapalıysa password
                value={password} 
                onChange={(e) => setPassword(e.target.value)} 
                style={{ ...styles.input, width: '100%', paddingRight: '40px' }} 
                placeholder="••••••••"
                required 
              />
              {/* 3. GÖZ İKONU BUTONU */}
              <button 
                type="button"
                onClick={() => setShowPassword(!showPassword)}
                style={{ position: 'absolute', right: '10px', top: '50%', transform: 'translateY(-50%)', background: 'none', border: 'none', cursor: 'pointer', fontSize: '18px' }}
              >
                {showPassword ? '🙈' : '👁️'}
              </button>
            </div>
          </div>

          <button type="submit" style={styles.button} disabled={isLoading}>
            {isLoading ? 'Giriş Yapılıyor...' : 'Panele Giriş Yap 🚀'}
          </button>
        </form>
      </div>
    </div>
  );
}

// CSS stilleri aynı kalıyor...
const styles = {
  container: { display: 'flex', justifyContent: 'center', alignItems: 'center', height: '100vh', backgroundColor: '#f3f4f6' },
  card: { backgroundColor: 'white', padding: '40px', borderRadius: '12px', boxShadow: '0 4px 6px rgba(0,0,0,0.1)', width: '100%', maxWidth: '400px' },
  header: { textAlign: 'center', marginBottom: '30px' },
  title: { color: '#FF7A00', margin: '0 0 10px 0', fontSize: '28px' },
  subtitle: { color: '#6b7280', margin: 0, fontWeight: 'bold' },
  error: { backgroundColor: '#fee2e2', color: '#dc2626', padding: '12px', borderRadius: '8px', marginBottom: '20px', textAlign: 'center', fontSize: '14px', fontWeight: 'bold' },
  form: { display: 'flex', flexDirection: 'column', gap: '20px' },
  inputGroup: { display: 'flex', flexDirection: 'column', gap: '8px' },
  label: { fontSize: '14px', color: '#374151', fontWeight: 'bold' },
  input: { padding: '12px', borderRadius: '8px', border: '1px solid #d1d5db', fontSize: '16px', outline: 'none', boxSizing: 'border-box' },
  button: { backgroundColor: '#FF7A00', color: 'white', padding: '14px', borderRadius: '8px', border: 'none', fontSize: '16px', fontWeight: 'bold', cursor: 'pointer', marginTop: '10px' }
};