import '../../../core/constants/couriers.dart';
import 'parcel.dart';

/// True for a synthetic card-payment or mall order-confirmation "parcel"
/// that has no real shipment info yet — see [Couriers.cardOrder] and
/// [Couriers.mallOrder]. A payment or order confirmation is a
/// point-in-time event, not an ongoing shipment: it only ever appears on
/// its registration day (parcel_day_index.dart) and never counts toward
/// the active/done shipment lists (parcel_repository.dart).
bool isOrderPlaceholder(Parcel p) =>
    p.courierCode == Couriers.cardOrder.code ||
    p.courierCode == Couriers.mallOrder.code;
