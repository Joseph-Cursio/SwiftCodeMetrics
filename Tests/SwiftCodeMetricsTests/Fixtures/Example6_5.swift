func cityLabel(for order: Order?) -> String {
    let city = order?.customer?.address?.city?.capitalized
    order?.delegate?.didRequestLabel(for: order)
    return city ?? "Unknown"
}
