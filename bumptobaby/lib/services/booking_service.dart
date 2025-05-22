import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

class BookingService {
  // Store user's booking history
  Future<void> saveBooking({
    required String placeId,
    required String placeName,
    required String serviceType,
    required DateTime appointmentDate,
    required String notes,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingsJson = prefs.getString('bookings') ?? '[]';
      final bookings = List<Map<String, dynamic>>.from(
        jsonDecode(bookingsJson).map((item) => Map<String, dynamic>.from(item)),
      );

      // Add new booking
      bookings.add({
        'id': 'booking_${DateTime.now().millisecondsSinceEpoch}',
        'placeId': placeId,
        'placeName': placeName,
        'serviceType': serviceType,
        'appointmentDate': appointmentDate.toIso8601String(),
        'status': 'pending',
        'notes': notes,
        'createdAt': DateTime.now().toIso8601String(),
      });

      // Save updated bookings
      await prefs.setString('bookings', jsonEncode(bookings));
    } catch (e) {
      debugPrint('Error saving booking: $e');
      throw Exception('Failed to save booking: $e');
    }
  }

  // Get user's booking history
  Future<List<Map<String, dynamic>>> getBookings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingsJson = prefs.getString('bookings') ?? '[]';
      final bookings = List<Map<String, dynamic>>.from(
        jsonDecode(bookingsJson).map((item) => Map<String, dynamic>.from(item)),
      );
      return bookings;
    } catch (e) {
      debugPrint('Error getting bookings: $e');
      return [];
    }
  }

  // Cancel a booking
  Future<bool> cancelBooking(String bookingId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final bookingsJson = prefs.getString('bookings') ?? '[]';
      final bookings = List<Map<String, dynamic>>.from(
        jsonDecode(bookingsJson).map((item) => Map<String, dynamic>.from(item)),
      );

      // Find and update booking status
      final index = bookings.indexWhere((booking) => booking['id'] == bookingId);
      if (index != -1) {
        bookings[index]['status'] = 'cancelled';
        bookings[index]['updatedAt'] = DateTime.now().toIso8601String();
        await prefs.setString('bookings', jsonEncode(bookings));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error cancelling booking: $e');
      return false;
    }
  }
}

class PharmacyService {
  // Store user's medication orders
  Future<void> saveOrder({
    required String pharmacyId,
    required String pharmacyName,
    required List<Map<String, dynamic>> medications,
    required String deliveryAddress,
    required String contactNumber,
  }) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('pharmacy_orders') ?? '[]';
      final orders = List<Map<String, dynamic>>.from(
        jsonDecode(ordersJson).map((item) => Map<String, dynamic>.from(item)),
      );

      // Calculate total price
      double totalPrice = 0;
      for (var med in medications) {
        totalPrice += (med['price'] as double) * (med['quantity'] as int);
      }

      // Add new order
      orders.add({
        'id': 'order_${DateTime.now().millisecondsSinceEpoch}',
        'pharmacyId': pharmacyId,
        'pharmacyName': pharmacyName,
        'medications': medications,
        'totalPrice': totalPrice,
        'deliveryAddress': deliveryAddress,
        'contactNumber': contactNumber,
        'status': 'processing',
        'createdAt': DateTime.now().toIso8601String(),
        'estimatedDelivery': DateTime.now().add(const Duration(days: 1)).toIso8601String(),
      });

      // Save updated orders
      await prefs.setString('pharmacy_orders', jsonEncode(orders));
    } catch (e) {
      debugPrint('Error saving order: $e');
      throw Exception('Failed to save order: $e');
    }
  }

  // Get user's medication orders
  Future<List<Map<String, dynamic>>> getOrders() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('pharmacy_orders') ?? '[]';
      final orders = List<Map<String, dynamic>>.from(
        jsonDecode(ordersJson).map((item) => Map<String, dynamic>.from(item)),
      );
      return orders;
    } catch (e) {
      debugPrint('Error getting orders: $e');
      return [];
    }
  }

  // Cancel an order
  Future<bool> cancelOrder(String orderId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final ordersJson = prefs.getString('pharmacy_orders') ?? '[]';
      final orders = List<Map<String, dynamic>>.from(
        jsonDecode(ordersJson).map((item) => Map<String, dynamic>.from(item)),
      );

      // Find and update order status
      final index = orders.indexWhere((order) => order['id'] == orderId);
      if (index != -1) {
        orders[index]['status'] = 'cancelled';
        orders[index]['updatedAt'] = DateTime.now().toIso8601String();
        await prefs.setString('pharmacy_orders', jsonEncode(orders));
        return true;
      }
      return false;
    } catch (e) {
      debugPrint('Error cancelling order: $e');
      return false;
    }
  }

  // Get available medications (mock data)
  List<Map<String, dynamic>> getAvailableMedications() {
    return [
      {
        'id': 'med_001',
        'name': 'Prenatal Vitamins',
        'description': 'Essential vitamins for pregnancy',
        'price': 25.99,
        'category': 'vitamins',
        'requiresPrescription': false,
        'imageUrl': 'https://example.com/prenatal_vitamins.jpg',
      },
      {
        'id': 'med_002',
        'name': 'Folic Acid Supplements',
        'description': 'Supports healthy fetal development',
        'price': 15.50,
        'category': 'supplements',
        'requiresPrescription': false,
        'imageUrl': 'https://example.com/folic_acid.jpg',
      },
      {
        'id': 'med_003',
        'name': 'Iron Supplements',
        'description': 'Prevents anemia during pregnancy',
        'price': 18.75,
        'category': 'supplements',
        'requiresPrescription': false,
        'imageUrl': 'https://example.com/iron_supplements.jpg',
      },
      {
        'id': 'med_004',
        'name': 'Contraceptive Pills',
        'description': 'Birth control pills',
        'price': 35.00,
        'category': 'contraceptives',
        'requiresPrescription': true,
        'imageUrl': 'https://example.com/contraceptive_pills.jpg',
      },
      {
        'id': 'med_005',
        'name': 'Postpartum Pain Relief',
        'description': 'Safe pain relievers for new mothers',
        'price': 22.99,
        'category': 'pain_relief',
        'requiresPrescription': false,
        'imageUrl': 'https://example.com/pain_relief.jpg',
      },
      {
        'id': 'med_006',
        'name': 'Morning Sickness Medication',
        'description': 'Relief from nausea during pregnancy',
        'price': 29.50,
        'category': 'nausea_relief',
        'requiresPrescription': true,
        'imageUrl': 'https://example.com/nausea_relief.jpg',
      },
    ];
  }

  // Get vaccination packages (mock data)
  List<Map<String, dynamic>> getVaccinationPackages() {
    return [
      {
        'id': 'vac_001',
        'name': 'Basic Infant Vaccination Package',
        'description': 'Essential vaccines for infants 0-12 months',
        'price': 150.00,
        'vaccines': [
          'BCG (Tuberculosis)',
          'Hepatitis B',
          'DTaP (Diphtheria, Tetanus, Pertussis)',
          'IPV (Polio)',
          'Hib (Haemophilus influenzae type b)',
        ],
        'imageUrl': 'https://example.com/infant_vaccines.jpg',
      },
      {
        'id': 'vac_002',
        'name': 'Toddler Vaccination Package',
        'description': 'Recommended vaccines for children 1-4 years',
        'price': 180.00,
        'vaccines': [
          'MMR (Measles, Mumps, Rubella)',
          'Varicella (Chickenpox)',
          'Hepatitis A',
          'DTaP Booster',
          'IPV Booster',
        ],
        'imageUrl': 'https://example.com/toddler_vaccines.jpg',
      },
      {
        'id': 'vac_003',
        'name': 'Pregnancy Vaccination Package',
        'description': 'Recommended vaccines during pregnancy',
        'price': 120.00,
        'vaccines': [
          'Tdap (Tetanus, Diphtheria, Pertussis)',
          'Influenza (Flu)',
          'COVID-19 (if applicable)',
        ],
        'imageUrl': 'https://example.com/pregnancy_vaccines.jpg',
      },
    ];
  }

  // Get available milk formula options with market prices
  List<Map<String, dynamic>> getAvailableMilkFormula() {
    return [
      {
        'id': 'formula_001',
        'name': 'Enfamil NeuroPro Infant Formula',
        'description': 'For babies 0-12 months, brain-building nutrition',
        'price': 39.99,
        'size': '20.7 oz',
        'availability': 'Most pharmacies and supermarkets',
        'rating': 4.7,
        'imageUrl': 'https://example.com/enfamil.jpg',
      },
      {
        'id': 'formula_002',
        'name': 'Similac Pro-Advance',
        'description': 'With 2\'-FL HMO for immune support, 0-12 months',
        'price': 36.99,
        'size': '23.2 oz',
        'availability': 'Nationwide at major retailers',
        'rating': 4.6,
        'imageUrl': 'https://example.com/similac.jpg',
      },
      {
        'id': 'formula_003',
        'name': 'Earth\'s Best Organic Dairy Formula',
        'description': 'USDA Organic, no artificial flavors or colors',
        'price': 29.99,
        'size': '21 oz',
        'availability': 'Organic stores and select pharmacies',
        'rating': 4.5,
        'imageUrl': 'https://example.com/earths_best.jpg',
      },
      {
        'id': 'formula_004',
        'name': 'Gerber Good Start GentlePro',
        'description': 'Easy to digest proteins for sensitive tummies',
        'price': 32.99,
        'size': '19.4 oz',
        'availability': 'Most grocery stores and pharmacies',
        'rating': 4.4,
        'imageUrl': 'https://example.com/gerber.jpg',
      },
      {
        'id': 'formula_005',
        'name': 'Aptamil Gold+ Baby Formula',
        'description': 'Premium formula with prebiotics and probiotics',
        'price': 42.99,
        'size': '28 oz',
        'availability': 'Select pharmacies and specialty stores',
        'rating': 4.8,
        'imageUrl': 'https://example.com/aptamil.jpg',
      },
    ];
  }
} 