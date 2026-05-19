const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt'); // Şifre kriptolayıcı
const jwt = require('jsonwebtoken'); // Dijital Biletçi
require('dotenv').config();
const Joi = require('joi');
const rateLimit = require('express-rate-limit');
const app = express();
require('dotenv').config();
app.use(cors());
app.use(express.json());
const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000, // 15 dakika
  max: 5, // Aynı IP'den 15 dakika içinde en fazla 5 deneme izni
  message: { success: false, message: 'Çok fazla giriş denemesi! Lütfen 15 dakika sonra tekrar deneyin.' },
  standardHeaders: true, 
  legacyHeaders: false,
});

const pool = new Pool({
  host: process.env.DB_HOST,
  user: process.env.DB_USER,
  password: process.env.DB_PASSWORD,
  database: process.env.DB_NAME,
  port: process.env.DB_PORT,
});

pool.connect()
  .then(() => console.log('✅ PostgreSQL bağlandı!'))
  .catch(err => console.error('❌ Veritabanı hatası:', err.stack));

// GÜVENLİK DUVARI: Sadece bileti (Token) olanları içeri alan fonksiyon
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1]; // "Bearer TOKEN" formatından token'ı ayıkla

  if (!token) return res.status(401).json({ success: false, message: 'Erişim reddedildi! Biletin yok.' });

  jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, user) => {
    if (err) return res.status(403).json({ success: false, message: 'Geçersiz veya süresi dolmuş bilet!' });
    req.user = user; // Bilet onaylandı, kullanıcının kimliğini (ID) isteğin içine koy
    next(); // Kapıyı aç, devam etmesine izin ver
  });
};


// GÜVENLİK DUVARI: Kayıt Verisi Kuralları (X-Ray)
const registerSchema = Joi.object({
  name: Joi.string().min(3).max(50).required().messages({
    'string.min': 'İşletme adı en az 3 karakter olmalıdır.',
    'string.max': 'İşletme adı 50 karakteri geçemez.',
    'string.empty': 'İşletme adı boş bırakılamaz.'
  }),
  // Telefon numarası tam 10 haneli olmalı ve sadece rakamlardan oluşmalı (örn: 5321234567)
  phone: Joi.string().length(10).pattern(/^[0-9]+$/).required().messages({
    'string.length': 'Telefon numarası tam 10 haneli olmalıdır (Başta 0 olmadan).',
    'string.pattern.base': 'Telefon numarası sadece rakamlardan oluşmalıdır.'
  }),
  password: Joi.string().min(6).required().messages({
    'string.min': 'Şifreniz güvenliğiniz için en az 6 karakter olmalıdır.'
  })
});


// 1. ESNAF KAYIT OL (Şifre Kriptolama)
app.post('/api/register', async (req, res) => {
  // Veriyi X-Ray'den geçir! Hata varsa içeri sokma, direkt cevap dön.
  const { error } = registerSchema.validate(req.body);
  if (error) {
    return res.status(400).json({ success: false, message: error.details[0].message });
  }

  const { phone, password, name } = req.body;
  try {
    // Şifreyi 10 katmanlı tuzlama (salt) ile kırılmaz hale getir
    const hashedPassword = await bcrypt.hash(password, 10); 
    
    const result = await pool.query(
      'INSERT INTO users (phone, password, name) VALUES ($1, $2, $3) RETURNING id, phone, name',
      [phone, hashedPassword, name]
    );
    res.json({ success: true, user: result.rows[0], message: 'Kayıt başarılı!' });
  } catch (err) {
    if (err.code === '23505') return res.status(400).json({ error: 'Bu telefon numarası zaten kayıtlı.' });
    res.status(500).json({ error: 'Kayıt hatası' });
  }
});

// 2. ESNAF GİRİŞ YAP (Şifre Kontrolü ve JWT Üretimi)
app.post('/api/login', loginLimiter, async (req, res) => {
  const { phone, password } = req.body;
  try {
    // 1. Kullanıcıyı bul
    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) return res.status(401).json({ success: false, message: 'Kullanıcı bulunamadı!' });

    const user = result.rows[0];

    // 2. Girilen şifre ile veritabanındaki kriptolu şifreyi eşleştir
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) return res.status(401).json({ error: 'Hatalı şifre' });

    // SİHİRLİ DOKUNUŞ: Artık 2 farklı bilet basıyoruz!
    // HATA DÜZELTİLDİ: user.rows[0].id yerine sadece user.id yazdık!
    
    // 1. Kısa Ömürlü Bilet (Sadece 15 Dakika)
    const accessToken = jwt.sign({ id: user.id }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
    
    // 2. Uzun Ömürlü VIP Bilet (7 Gün)
    const refreshToken = jwt.sign({ id: user.id }, process.env.REFRESH_TOKEN_SECRET, { expiresIn: '7d' });

    res.json({ 
      success: true, 
      message: 'Giriş başarılı!', 
      accessToken: accessToken, 
      refreshToken: refreshToken 
    });

  } catch (err) {
    console.error("LOGIN ÇÖKME HATASI:", err); // Sunucu çökerse terminalde görelim
    res.status(500).json({ error: 'Giriş hatası' });
  }
});

// 3. KAMPANYALARI GETİR (Herkes görebilir, bilet gerekmez)
app.get('/api/campaigns', async (req, res) => {
  const { city, district, category } = req.query;
  let query = 'SELECT * FROM campaigns WHERE 1=1';
  let values = [];
  let counter = 1;

  if (city && city !== 'Tümü') { query += ` AND city = $${counter}`; values.push(city); counter++; }
  if (district) { query += ` AND district = $${counter}`; values.push(district); counter++; }
  if (category && category !== 'Tümü') { query += ` AND category = $${counter}`; values.push(category); counter++; }

  query += ' ORDER BY created_at DESC';

  try {
    const result = await pool.query(query, values);
    res.json(result.rows);
  } catch (err) {
    res.status(500).json({ error: 'Sunucu hatası' });
  }
});

// 4. YENİ KAMPANYA EKLE (DİKKAT: authenticateToken ile KORUMA ALTINDA!)
app.post('/api/campaigns', authenticateToken, async (req, res) => {
  // Artık user_id'yi Flutter'dan güvenmeyip, direkt doğrulanan Token'ın içinden alıyoruz!
  const userId = req.user.id; 
  const { title, description, category, city, district, address, end_date } = req.body;
  
  try {
    const result = await pool.query(
      `INSERT INTO campaigns (user_id, title, description, category, city, district, address, end_date) 
       VALUES ($1, $2, $3, $4, $5, $6, $7, $8) RETURNING *`,
      [userId, title, description, category, city, district, address, end_date]
    );
    res.json({ success: true, campaign: result.rows[0] });
  } catch (err) {
    res.status(500).json({ error: 'Kampanya eklenemedi' });
  }
});

// 5. KAMPANYA SİL (IDOR KORUMALI)
app.delete('/api/campaigns/:id', authenticateToken, async (req, res) => {
  const campaignId = req.params.id; // URL'den gelen silinecek kampanya ID'si
  const userId = req.user.id;       // Giren esnafın JWT token'ından çözülen kendi ID'si

  try {
    // SİHİRLİ DOKUNUŞ: Sadece 'id' ile değil, 'user_id' ile de eşleştiriyoruz!
    // Yani "Silinmesi istenen kampanya ID'si bu mu VE bu kampanya bu esnafa mı ait?"
    const result = await pool.query(
      'DELETE FROM campaigns WHERE id = $1 AND user_id = $2 RETURNING *',
      [campaignId, userId]
    );

    // Eğer silinen satır yoksa, ya kampanya yoktur ya da BAŞKASININDIR!
    if (result.rows.length === 0) {
      return res.status(403).json({ 
        success: false, 
        message: 'Erişim reddedildi! Bu kampanya size ait değil veya bulunamadı.' 
      });
    }

    res.json({ success: true, message: 'Kampanya başarıyla silindi!' });
  } catch (err) {
    console.error("🚨 SİLME HATASI:", err);
    res.status(500).json({ error: 'Kampanya silinirken bir hata oluştu.' });
  }
});

// 6. YENİ BİLET ALMA KAPISI (Refresh Token)
app.post('/api/refresh', (req, res) => {
  const { refreshToken } = req.body;

  // Eğer adamın elinde VIP kart yoksa direkt kapı dışarı et
  if (!refreshToken) return res.status(401).json({ error: 'Refresh token gerekli!' });

  // VIP Kart sahte mi, süresi mi dolmuş kontrol et
  jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Geçersiz veya süresi dolmuş refresh token!' });

    // Kart gerçekse, ona yepyeni bir 15 dakikalık bilet bas ve gönder!
    const newAccessToken = jwt.sign({ id: user.id }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
    res.json({ accessToken: newAccessToken });
  });
});

// SUNUCUYU AYAĞA KALDIR (KAPILARI AÇ)
const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Sunucu ${PORT} portunda çalışıyor!`);
});