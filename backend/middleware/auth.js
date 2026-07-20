const jwt = require('jsonwebtoken');

function requireAuth(req, res, next) {
  const header = req.headers.authorization;
  if (!header || !header.startsWith('Bearer ')) {
    return res.status(401).json({ error: 'يجب تسجيل الدخول' });
  }

  const token = header.slice('Bearer '.length);
  try {
    req.user = jwt.verify(token, process.env.JWT_SECRET);
    next();
  } catch (err) {
    return res.status(401).json({ error: 'جلسة غير صالحة، يرجى تسجيل الدخول مجدداً' });
  }
}

function requireRole(role) {
  return (req, res, next) => {
    if (req.user.role !== role) {
      return res.status(403).json({ error: 'لا تملك صلاحية القيام بهذا الإجراء' });
    }
    next();
  };
}

module.exports = { requireAuth, requireRole };
