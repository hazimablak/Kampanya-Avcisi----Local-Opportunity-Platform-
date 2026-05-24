const express = require('express');
const cors = require('cors');
const { Pool } = require('pg');
const bcrypt = require('bcrypt'); 
const jwt = require('jsonwebtoken'); 
const Joi = require('joi');
const rateLimit = require('express-rate-limit');
require('dotenv').config();

const app = express();
app.use(cors());
app.use(express.json());

const loginLimiter = rateLimit({
  windowMs: 15 * 60 * 1000,
  max: 5,
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

// GÜVENLİK DUVARI
const authenticateToken = (req, res, next) => {
  const authHeader = req.headers['authorization'];
  const token = authHeader && authHeader.split(' ')[1];

  if (!token) return res.status(401).json({ success: false, message: 'Erişim reddedildi! Biletin yok.' });

  jwt.verify(token, process.env.ACCESS_TOKEN_SECRET, (err, user) => {
    if (err) return res.status(403).json({ success: false, message: 'Geçersiz veya süresi dolmuş bilet!' });
    req.user = user; 
    next(); 
  });
};

const registerSchema = Joi.object({
  name: Joi.string().min(3).max(50).required(),
  phone: Joi.string().length(10).pattern(/^[0-9]+$/).required(),
  password: Joi.string().min(6).required()
});

// 1. ESNAF KAYIT OL
app.post('/api/register', async (req, res) => {
  const { error } = registerSchema.validate(req.body);
  if (error) return res.status(400).json({ success: false, message: error.details[0].message });

  const { phone, password, name } = req.body;
  try {
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

// 2. ESNAF GİRİŞ YAP (.ENV ADMİN KONTROLÜ EKLENDİ)
app.post('/api/login', loginLimiter, async (req, res) => {
  const { phone, password } = req.body;
  try {
    const result = await pool.query('SELECT * FROM users WHERE phone = $1', [phone]);
    if (result.rows.length === 0) return res.status(401).json({ success: false, message: 'Kullanıcı bulunamadı!' });

    const user = result.rows[0];
    const validPassword = await bcrypt.compare(password, user.password);
    if (!validPassword) return res.status(401).json({ error: 'Hatalı şifre' });

    // .env dosyasındaki numara ile giriş yapan numara eşleşiyor mu?
    const isAdmin = user.phone === process.env.ADMIN_PHONE;

    // Tokenların içine isAdmin (true/false) bilgisini de ekliyoruz
    const accessToken = jwt.sign({ id: user.id, isAdmin: isAdmin }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
    const refreshToken = jwt.sign({ id: user.id, isAdmin: isAdmin }, process.env.REFRESH_TOKEN_SECRET, { expiresIn: '7d' });

    res.json({ 
      success: true, 
      message: 'Giriş başarılı!', 
      accessToken, 
      refreshToken,
      isAdmin // Frontend'e bu adamın admin olup olmadığını söylüyoruz
    });

  } catch (err) {
    console.error("LOGIN ÇÖKME HATASI:", err); 
    res.status(500).json({ error: 'Giriş hatası' });
  }
});

// 3. KAMPANYALARI GETİR
app.get('/api/campaigns', async (req, res) => {
  const { city, district, category } = req.query;
  let query = `SELECT c.*, u.phone AS merchant_phone FROM campaigns c INNER JOIN users u ON c.user_id = u.id WHERE c.end_date >= CURRENT_DATE`;
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

// 4. YENİ KAMPANYA EKLE
app.post('/api/campaigns', authenticateToken, async (req, res) => {
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

// 5. KAMPANYA SİL (ADMİN İSE HER ŞEYİ SİLEBİLİR)
app.delete('/api/campaigns/:id', authenticateToken, async (req, res) => {
  const campaignId = req.params.id;
  const userId = req.user.id;      
  const isAdmin = req.user.isAdmin; // Token'dan admin yetkisini okuduk

  try {
    let result;
    
    // Eğer adminsen, kampanya kimin olursa olsun SİL. Değilsen, sadece kendi kampanyanı sil!
    if (isAdmin) {
      result = await pool.query('DELETE FROM campaigns WHERE id = $1 RETURNING *', [campaignId]);
    } else {
      result = await pool.query('DELETE FROM campaigns WHERE id = $1 AND user_id = $2 RETURNING *', [campaignId, userId]);
    }

    if (result.rows.length === 0) {
      return res.status(403).json({ success: false, message: 'Erişim reddedildi! Bu kampanya size ait değil.' });
    }

    res.json({ success: true, message: 'Kampanya başarıyla silindi!' });
  } catch (err) {
    console.error("🚨 SİLME HATASI:", err);
    res.status(500).json({ error: 'Kampanya silinirken bir hata oluştu.' });
  }
});

// 6. YENİ BİLET ALMA
app.post('/api/refresh', (req, res) => {
  const { refreshToken } = req.body;
  if (!refreshToken) return res.status(401).json({ error: 'Refresh token gerekli!' });

  jwt.verify(refreshToken, process.env.REFRESH_TOKEN_SECRET, (err, user) => {
    if (err) return res.status(403).json({ error: 'Geçersiz veya süresi dolmuş refresh token!' });
    
    // Yeni bilet oluştururken isAdmin yetkisini tekrar içine koyuyoruz
    const newAccessToken = jwt.sign({ id: user.id, isAdmin: user.isAdmin }, process.env.ACCESS_TOKEN_SECRET, { expiresIn: '15m' });
    res.json({ accessToken: newAccessToken });
  });
});

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => {
  console.log(`🚀 Sunucu ${PORT} portunda çalışıyor!`);
});