const express = require('express');
const router = express.Router();
const rideController = require('../controllers/rideController');
const { authenticate } = require('../middleware/auth');

router.get('/search', rideController.searchRides);
router.get('/my-rides', authenticate, rideController.getMyRides);
router.get('/:id', rideController.getRideById);
router.post('/', authenticate, rideController.createRide);
router.post('/book', authenticate, rideController.bookRide);
router.post('/verify-otp', authenticate, rideController.verifyOtp);
router.post('/complete', authenticate, rideController.completeRide);

module.exports = router;
