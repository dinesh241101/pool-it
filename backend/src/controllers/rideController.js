const prisma = require('../config/database');

exports.createRide = async (req, res) => {
  try {
    const {
      source, destination, intermediateStops, dateTime,
      availableSeats, totalSeats, farePerSeat, vehicleId,
    } = req.body;

    if (!source || !destination || !dateTime || !availableSeats || !farePerSeat) {
      return res.status(400).json({ error: 'Missing required fields' });
    }

    const ride = await prisma.ride.create({
      data: {
        driverId: req.user.id,
        source,
        destination,
        intermediateStops: intermediateStops || [],
        dateTime: new Date(dateTime),
        availableSeats: parseInt(availableSeats),
        totalSeats: parseInt(totalSeats || availableSeats),
        farePerSeat: parseFloat(farePerSeat),
        status: 'active',
        vehicleId: vehicleId || null,
      },
      include: { driver: { select: { id: true, name: true } } },
    });

    res.status(201).json({ message: 'Ride created successfully', ride });
  } catch (error) {
    console.error('Create ride error:', error);
    res.status(500).json({ error: 'Failed to create ride' });
  }
};

exports.searchRides = async (req, res) => {
  try {
    const { source, destination, date } = req.query;

    const where = { status: 'active' };
    if (source) where.source = { contains: source, mode: 'insensitive' };
    if (destination) where.destination = { contains: destination, mode: 'insensitive' };
    if (date) {
      const searchDate = new Date(date);
      where.dateTime = {
        gte: new Date(searchDate.setHours(0, 0, 0, 0)),
        lte: new Date(searchDate.setHours(23, 59, 59, 999)),
      };
    }

    const rides = await prisma.ride.findMany({
      where,
      include: {
        driver: { select: { id: true, name: true } },
        vehicle: true,
      },
      orderBy: { dateTime: 'asc' },
    });

    res.json({ rides });
  } catch (error) {
    console.error('Search rides error:', error);
    res.status(500).json({ error: 'Failed to search rides' });
  }
};

exports.getRideById = async (req, res) => {
  try {
    const { id } = req.params;
    const ride = await prisma.ride.findUnique({
      where: { id },
      include: {
        driver: { select: { id: true, name: true, phone: true } },
        vehicle: true,
      },
    });

    if (!ride) {
      return res.status(404).json({ error: 'Ride not found' });
    }

    res.json({ ride });
  } catch (error) {
    console.error('Get ride error:', error);
    res.status(500).json({ error: 'Failed to fetch ride' });
  }
};

exports.bookRide = async (req, res) => {
  try {
    const { rideId, seats } = req.body;

    const ride = await prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) return res.status(404).json({ error: 'Ride not found' });
    if (ride.status !== 'active') return res.status(400).json({ error: 'Ride is not available' });
    if (ride.availableSeats < seats) return res.status(400).json({ error: 'Not enough seats' });

    const otp = Math.floor(100000 + Math.random() * 900000).toString();

    const booking = await prisma.booking.create({
      data: {
        rideId,
        riderId: req.user.id,
        seatsBooked: seats,
        totalFare: ride.farePerSeat * seats,
        otp,
        otpExpiry: new Date(Date.now() + 10 * 60 * 1000),
        status: 'confirmed',
      },
    });

    await prisma.ride.update({
      where: { id: rideId },
      data: { availableSeats: ride.availableSeats - seats },
    });

    res.status(201).json({ message: 'Booking confirmed', booking });
  } catch (error) {
    console.error('Book ride error:', error);
    res.status(500).json({ error: 'Failed to book ride' });
  }
};

exports.verifyOtp = async (req, res) => {
  try {
    const { bookingId, otp } = req.body;

    const booking = await prisma.booking.findUnique({ where: { id: bookingId } });
    if (!booking) return res.status(404).json({ error: 'Booking not found' });
    if (booking.otpAttempts >= 3) return res.status(400).json({ error: 'Max OTP attempts exceeded' });
    if (new Date() > booking.otpExpiry) return res.status(400).json({ error: 'OTP expired' });

    if (booking.otp !== otp) {
      await prisma.booking.update({
        where: { id: bookingId },
        data: { otpAttempts: booking.otpAttempts + 1 },
      });
      return res.status(400).json({ error: 'Invalid OTP' });
    }

    await prisma.booking.update({
      where: { id: bookingId },
      data: { status: 'started', otpAttempts: booking.otpAttempts + 1 },
    });

    await prisma.ride.update({
      where: { id: booking.rideId },
      data: { status: 'started' },
    });

    res.json({ message: 'OTP verified. Ride started!' });
  } catch (error) {
    console.error('Verify OTP error:', error);
    res.status(500).json({ error: 'OTP verification failed' });
  }
};

exports.completeRide = async (req, res) => {
  try {
    const { rideId } = req.body;

    const ride = await prisma.ride.findUnique({ where: { id: rideId } });
    if (!ride) return res.status(404).json({ error: 'Ride not found' });
    if (ride.driverId !== req.user.id) return res.status(403).json({ error: 'Unauthorized' });

    await prisma.ride.update({
      where: { id: rideId },
      data: { status: 'completed' },
    });

    await prisma.booking.updateMany({
      where: { rideId, status: { in: ['confirmed', 'started'] } },
      data: { status: 'completed' },
    });

    res.json({ message: 'Ride completed successfully' });
  } catch (error) {
    console.error('Complete ride error:', error);
    res.status(500).json({ error: 'Failed to complete ride' });
  }
};

exports.getMyRides = async (req, res) => {
  try {
    const rides = await prisma.ride.findMany({
      where: { driverId: req.user.id },
      include: {
        bookings: { include: { rider: { select: { id: true, name: true } } } },
      },
      orderBy: { dateTime: 'desc' },
    });

    res.json({ rides });
  } catch (error) {
    console.error('Get my rides error:', error);
    res.status(500).json({ error: 'Failed to fetch rides' });
  }
};
