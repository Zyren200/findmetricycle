import "../../passenger/repositories/passenger_repository.dart";

class BookingRepository {
  BookingRepository(this._passengerRepository);

  final PassengerRepository _passengerRepository;

  Future<Map<String, dynamic>> cancel(int bookingId) {
    return _passengerRepository.cancelBooking(bookingId);
  }

  Future<Map<String, dynamic>> rate({
    required int bookingId,
    required int stars,
    required String feedback,
  }) {
    return _passengerRepository.submitRating(
      bookingId: bookingId,
      stars: stars,
      feedback: feedback,
    );
  }
}
