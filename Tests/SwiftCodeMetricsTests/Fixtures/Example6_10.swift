func depth(of node: TreeNode?) -> Int {
    guard let node else { return 0 }
    return 1 + max(depth(of: node.left), depth(of: node.right))
}
