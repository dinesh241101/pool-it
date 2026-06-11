const express = require('express');
const router = express.Router();
const userController = require('../controllers/userController');
const { authenticate } = require('../middleware/auth');

router.get('/profile', authenticate, userController.getProfile);
router.put('/profile', authenticate, userController.updateProfile);
router.post('/vehicles', authenticate, userController.registerVehicle);
router.get('/vehicles', authenticate, userController.getMyVehicles);

module.exports = router;
