import React, { useState, useEffect } from 'react';
import Login from './Login';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);

  // Sayfa yenilendiğinde kasada (localStorage) bilet var mı diye bak
  useEffect(() => {
    const token = localStorage.getItem('adminToken');
    if (token) {
      setIsAuthenticated(true);
    }
  }, []);

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    setIsAuthenticated(false);
  };

  // EĞER GİRİŞ YAPMADIYSA LOGIN EKRANINI GÖSTER
  if (!isAuthenticated) {
    return <Login onLoginSuccess={() => setIsAuthenticated(true)} />;
  }

  // EĞER GİRİŞ YAPTIYSA ADMIN PANELİNİ GÖSTER (Şimdilik geçici ekran)
  return (
    <div style={{ padding: '20px', fontFamily: 'sans-serif' }}>
      <div style={{ display: 'flex', justifyContent: 'space-between', alignItems: 'center', borderBottom: '2px solid #FF7A00', paddingBottom: '10px' }}>
        <h1 style={{ color: '#FF7A00' }}>👑 Hoş Geldin Admin (Niko)</h1>
        <button 
          onClick={handleLogout} 
          style={{ backgroundColor: '#dc2626', color: 'white', padding: '10px 20px', border: 'none', borderRadius: '8px', cursor: 'pointer', fontWeight: 'bold' }}>
          Çıkış Yap
        </button>
      </div>
      
      <h2 style={{ marginTop: '20px' }}>Dashboard Yükleniyor...</h2>
      <p>Buraya esnaflar tablosunu, kampanyalar tablosunu ve istatistikleri çekeceğiz!</p>
    </div>
  );
}

export default App;