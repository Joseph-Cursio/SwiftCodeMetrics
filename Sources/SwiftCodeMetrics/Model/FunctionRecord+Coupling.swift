//
//  FunctionRecord+Coupling.swift
//  SwiftCodeMetrics
//
//  Copies of a record for the module pass: renumbered into the module's
//  array, then given its coupling values.
//

extension FunctionRecord {
    /// The record with its ids shifted by `offset`.
    func moved(by offset: Int) -> Self {
        Self(
            id: id + offset,
            parentID: parentID.map { $0 + offset },
            key: key,
            parentKey: parentKey,
            kind: kind,
            name: name,
            range: range,
            lines: lines,
            complexity: complexity,
            couplingStatus: couplingStatus,
            parameters: parameters,
            fanOut: fanOut,
            commonCoupling: commonCoupling,
            typeReferences: typeReferences
        )
    }

    /// The record with final coupling values.
    func withCoupling(
        parameters: ParameterCounts?,
        fanOut: FanOut,
        commonCoupling: CommonCoupling,
        typeReferences: [TypeReference]
    ) -> Self {
        Self(
            id: id,
            parentID: parentID,
            key: key,
            parentKey: parentKey,
            kind: kind,
            name: name,
            range: range,
            lines: lines,
            complexity: complexity,
            couplingStatus: .computed,
            parameters: parameters,
            fanOut: fanOut,
            commonCoupling: commonCoupling,
            typeReferences: typeReferences
        )
    }
}
