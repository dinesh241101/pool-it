const prisma = require('../config/database');

exports.updateProfile = async (req, res) => {
  try {
    const { name, email, emergencyContact } = req.body;

    const data = {};
    if (name !== undefined) data.name = name;
    if (email !== undefined) data.email = email;
    if (emergencyContact !== undefined) data.emergencyContact = emergencyContact;

    const user = await prisma.user.update({
      where: { id: req.user.id },
      data,
      select: {
        id: true, name: true, phone: true, email: true,
        emergencyContact: true, isDriver: true, isLicenseVerified: true,
      },
    });

    res.json({ message: 'Profile updated', user });
  } catch (error) {
    console.error('Update profile error:', error);
    res.status(500).json({ error: 'Failed to update profile' });
  }
};

exports.getProfile = async (req, res) => {
  try {
    const user = await prisma.user.findUnique({
      where: { id: req.user.id },
      select: {
        id: true, name: true, phone: true, email: true,
        profilePic: true, emergencyContact: true,
        isDriver: true, isLicenseVerified: true,
        vehicles: true,
        createdAt: true,
      },
    });

    if (!user) return res.status(404).json({ error: 'User not found' });
    res.json({ user });
  } catch (error) {
    console.error('Get profile error:', error);
    res.status(500).json({ error: 'Failed to fetch profile' });
  }
};

exports.registerVehicle = async (req, res) => {
  try {
    const { make, model, year, color, licensePlate, seats } = req.body;

    if (!make || !model || !licensePlate || !seats) {
      return res.status(400).json({ error: 'Missing required vehicle fields' });
    }

    const vehicle = await prisma.vehicle.create({
      data: {
        userId: req.user.id,
        make,
        model,
        year,
        color,
        licensePlate,
        seats: parseInt(seats),
      },
    });

    res.status(201).json({ message: 'Vehicle registered', vehicle });
  } catch (error) {
    console.error('Register vehicle error:', error);
    res.status(500).json({ error: 'Failed to register vehicle' });
  }
};

exports.getMyVehicles = async (req, res) => {
  try {
    const vehicles = await prisma.vehicle.findMany({
      where: { userId: req.user.id },
    });
    res.json({ vehicles });
  } catch (error) {
    console.error('Get vehicles error:', error);
    res.status(500).json({ error: 'Failed to fetch vehicles' });
  }
};
