import React, { useState, useEffect } from 'react';
import Login from './Login';
import api from './api';

function App() {
  const [isAuthenticated, setIsAuthenticated] = useState(false);
  const [activeTab, setActiveTab] = useState('campaigns'); // 'campaigns' veya 'users'
  
  const [campaigns, setCampaigns] = useState([]);
  const [users, setUsers] = useState([]);
  const [isLoading, setIsLoading] = useState(false);

  // Sayfa açıldığında kasada bilet var mı diye bak
  useEffect(() => {
    const token = localStorage.getItem('adminToken');
    if (token) setIsAuthenticated(true);
  }, []);

  // Giriş yapıldığı an verileri backend'den çekmeye başla
  useEffect(() => {
    if (isAuthenticated) {
      fetchCampaigns();
      fetchUsers();
    }
  }, [isAuthenticated]);

  const fetchCampaigns = async () => {
    setIsLoading(true);
    try {
      const res = await api.get('/api/campaigns');
      setCampaigns(res.data);
    } catch (err) {
      console.error('Kampanyalar çekilemedi', err);
    } finally {
      setIsLoading(false);
    }
  };

  const fetchUsers = async () => {
    try {
      const res = await api.get('/api/users');
      setUsers(res.data);
    } catch (err) {
      console.error('Kullanıcılar çekilemedi', err);
    }
  };

  // KAMPANYA SİLME İŞLEMİ (Adalet Çekici)
  const handleDeleteCampaign = async (id) => {
    const isConfirmed = window.confirm("Bu kampanyayı silmek istediğinize emin misiniz? Bu işlem geri alınamaz!");
    if (!isConfirmed) return;

    try {
      const res = await api.delete(`/api/campaigns/${id}`);
      if (res.status === 200) {
        alert("Kampanya başarıyla silindi!");
        fetchCampaigns(); // Tabloyu güncelle
      }
    } catch (err) {
      alert("Silme işlemi başarısız oldu. Yetkiniz olmayabilir.");
    }
  };

  const handleLogout = () => {
    localStorage.removeItem('adminToken');
    setIsAuthenticated(false);
  };

  // GİRİŞ YAPILMADIYSA GİRİŞ EKRANINI GÖSTER
  if (!isAuthenticated) {
    return <Login onLoginSuccess={() => setIsAuthenticated(true)} />;
  }

  // GİRİŞ YAPILDIYSA ANA PANELİ GÖSTER
  return (
    <div style={styles.container}>
      {/* SOL MENÜ (SIDEBAR) */}
      <div style={styles.sidebar}>
        <h2 style={styles.logo}>Kampanya<br/>Avcısı</h2>
        <p style={{color: '#9ca3af', fontSize: '12px', marginBottom: '30px'}}>Admin Paneli v1.0</p>
        
        <button 
          style={activeTab === 'campaigns' ? styles.activeTab : styles.tab} 
          onClick={() => setActiveTab('campaigns')}
        >
          📢 Kampanyalar
        </button>
        <button 
          style={activeTab === 'users' ? styles.activeTab : styles.tab} 
          onClick={() => setActiveTab('users')}
        >
          👥 Esnaflar
        </button>

        <div style={{ flexGrow: 1 }}></div>
        <button style={styles.logoutBtn} onClick={handleLogout}>🚪 Çıkış Yap</button>
      </div>

      {/* SAĞ İÇERİK ALANI */}
      <div style={styles.content}>
        <div style={styles.header}>
          <h1>{activeTab === 'campaigns' ? 'Tüm Kampanyalar' : 'Sistemdeki Esnaflar'}</h1>
          <div style={styles.badge}>Süper Admin Yetkisi 👑</div>
        </div>

        {isLoading ? (
          <p>Veriler yükleniyor...</p>
        ) : (
          <div style={styles.card}>
            {/* KAMPANYALAR TABLOSU */}
            {activeTab === 'campaigns' && (
              <table style={styles.table}>
                <thead>
                  <tr style={styles.tableHead}>
                    <th>ID</th>
                    <th>Başlık</th>
                    <th>Kategori</th>
                    <th>Şehir / İlçe</th>
                    <th>Esnaf Tel</th>
                    <th>İşlem</th>
                  </tr>
                </thead>
                <tbody>
                  {campaigns.length === 0 ? (<tr><td colSpan="6">Henüz kampanya yok.</td></tr>) : null}
                  {campaigns.map((camp) => (
                    <tr key={camp.id} style={styles.tableRow}>
                      <td>#{camp.id}</td>
                      <td style={{fontWeight: 'bold'}}>{camp.title}</td>
                      <td>{camp.category}</td>
                      <td>{camp.city} / {camp.district}</td>
                      <td>{camp.merchant_phone}</td>
                      <td>
                        <button 
                          style={styles.deleteBtn} 
                          onClick={() => handleDeleteCampaign(camp.id)}
                        >
                          Sil
                        </button>
                      </td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}

            {/* ESNAFLAR TABLOSU */}
            {activeTab === 'users' && (
              <table style={styles.table}>
                <thead>
                  <tr style={styles.tableHead}>
                    <th>Kullanıcı ID</th>
                    <th>İşletme Adı</th>
                    <th>Telefon Numarası</th>
                  </tr>
                </thead>
                <tbody>
                  {users.length === 0 ? (<tr><td colSpan="3">Henüz esnaf yok.</td></tr>) : null}
                  {users.map((user) => (
                    <tr key={user.id} style={styles.tableRow}>
                      <td>#{user.id}</td>
                      <td style={{fontWeight: 'bold'}}>{user.name}</td>
                      <td>{user.phone}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            )}
          </div>
        )}
      </div>
    </div>
  );
}

// YÖNETİM PANELİ CSS TASARIMLARI
const styles = {
  container: { display: 'flex', minHeight: '100vh', backgroundColor: '#f3f4f6', fontFamily: 'sans-serif' },
  sidebar: { width: '250px', backgroundColor: '#1f2937', color: 'white', display: 'flex', flexDirection: 'column', padding: '20px' },
  logo: { color: '#FF7A00', margin: '0 0 5px 0' },
  tab: { backgroundColor: 'transparent', color: '#d1d5db', border: 'none', padding: '15px', textAlign: 'left', fontSize: '16px', cursor: 'pointer', borderRadius: '8px', marginBottom: '10px', transition: '0.2s' },
  activeTab: { backgroundColor: '#FF7A00', color: 'white', border: 'none', padding: '15px', textAlign: 'left', fontSize: '16px', cursor: 'pointer', borderRadius: '8px', marginBottom: '10px', fontWeight: 'bold' },
  logoutBtn: { backgroundColor: '#ef4444', color: 'white', border: 'none', padding: '15px', textAlign: 'center', fontSize: '16px', cursor: 'pointer', borderRadius: '8px', fontWeight: 'bold' },
  content: { flex: 1, padding: '40px', overflowY: 'auto' },
  header: { display: 'flex', justifyContent: 'space-between', alignItems: 'center', marginBottom: '30px' },
  badge: { backgroundColor: '#fef08a', color: '#854d0e', padding: '8px 16px', borderRadius: '20px', fontWeight: 'bold', fontSize: '14px' },
  card: { backgroundColor: 'white', borderRadius: '12px', padding: '20px', boxShadow: '0 4px 6px rgba(0,0,0,0.05)' },
  table: { width: '100%', borderCollapse: 'collapse', textAlign: 'left' },
  tableHead: { backgroundColor: '#f9fafb', borderBottom: '2px solid #e5e7eb' },
  tableRow: { borderBottom: '1px solid #e5e7eb' },
  deleteBtn: { backgroundColor: '#fee2e2', color: '#dc2626', border: '1px solid #f87171', padding: '6px 12px', borderRadius: '6px', cursor: 'pointer', fontWeight: 'bold' }
};

export default App;