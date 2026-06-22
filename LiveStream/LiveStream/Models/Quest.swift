import Foundation

struct Quest: Identifiable, Hashable {
    let id = UUID()
    let name: String
    let icon: String
    let hourlyRate: Int
    let totalSubmissions: Int
    let streamsOnline: Int
    let avgDuration: Int // minutes
    let totalEarned: Int // dollars earned across all streamers

    static let samples: [Quest] = [
        Quest(name: "Load Dishwasher", icon: "dishwasher.fill", hourlyRate: 3, totalSubmissions: 1_243, streamsOnline: 18, avgDuration: 25, totalEarned: 4_870),
        Quest(name: "Fold Laundry", icon: "tshirt.fill", hourlyRate: 3, totalSubmissions: 2_891, streamsOnline: 42, avgDuration: 35, totalEarned: 12_340),
        Quest(name: "Vacuum Floors", icon: "fan.floor.fill", hourlyRate: 4, totalSubmissions: 987, streamsOnline: 11, avgDuration: 30, totalEarned: 6_210),
        Quest(name: "Take Out Trash", icon: "trash.fill", hourlyRate: 2, totalSubmissions: 4_512, streamsOnline: 67, avgDuration: 10, totalEarned: 8_920),
        Quest(name: "Mop Floors", icon: "square.grid.3x3.topleft.filled", hourlyRate: 4, totalSubmissions: 643, streamsOnline: 8, avgDuration: 40, totalEarned: 3_450),
        Quest(name: "Clean Bathroom", icon: "shower.fill", hourlyRate: 5, totalSubmissions: 1_876, streamsOnline: 23, avgDuration: 45, totalEarned: 15_780),
        Quest(name: "Organize Closet", icon: "cabinet.fill", hourlyRate: 4, totalSubmissions: 412, streamsOnline: 5, avgDuration: 50, totalEarned: 2_190),
        Quest(name: "Water Plants", icon: "leaf.fill", hourlyRate: 2, totalSubmissions: 3_204, streamsOnline: 31, avgDuration: 15, totalEarned: 5_640),
        Quest(name: "Wipe Counters", icon: "sparkles", hourlyRate: 2, totalSubmissions: 5_678, streamsOnline: 89, avgDuration: 12, totalEarned: 9_310),
        Quest(name: "Make Beds", icon: "bed.double.fill", hourlyRate: 2, totalSubmissions: 6_102, streamsOnline: 74, avgDuration: 8, totalEarned: 7_850),
    ]
}
