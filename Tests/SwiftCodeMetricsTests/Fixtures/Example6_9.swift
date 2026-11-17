var body: some View {
    List {
        if items.isEmpty {
            ContentUnavailableView("No items", systemImage: "tray")
        } else {
            ForEach(items) { item in
                HStack {
                    Text(item.title)
                    if item.isFlagged {
                        Image(systemName: "flag.fill")
                    }
                }
            }
        }
    }
    .toolbar {
        if canAdd {
            ToolbarItem { AddButton() }
        }
    }
}
