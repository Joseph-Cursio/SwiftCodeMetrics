func shippingCost(for order: Order) -> Decimal {
    let base: Decimal = switch order.region {
    case .domestic: 5
    case .europe: 12
    case .worldwide: 20
    }
    let express: Decimal = if order.isExpress { 10 } else { 0 }
    return order.total > 100 ? 0 : base + express
}
