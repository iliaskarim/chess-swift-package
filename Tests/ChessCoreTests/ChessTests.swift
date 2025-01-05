import XCTest
@testable import ChessCore

final class ChessTests: XCTestCase {
  func testFirstMoves() throws {
    let game = Game()

    XCTAssertTrue([.init("a3")!, .init("c3")!].allSatisfy(game.board.moves(from: .init("b1")!).contains))
    XCTAssertTrue([.init("f3")!, .init("h3")!].allSatisfy(game.board.moves(from: .init("g1")!).contains))

    for file in Square.File.allCases {
      XCTAssertTrue([
        .init(file: file, rank: .three),
        .init(file: file, rank: .four)
      ].allSatisfy(game.board.moves(from: .init(file: file, rank: .two)).contains))
    }
  }

  func testScholarsMate() throws {
    var game = Game()
    try game.move("e4")
    try game.move("e5")
    try game.move("Qh5")
    try game.move("Nc6")
    try game.move("Bc4")
    try game.move("Nf6")
    try game.move("Qxf7#")
    print(game)
    XCTAssertTrue(game.isGameOver)
  }

  func testStalemate() throws {
    var game = Game(board: .init(pieces: [
      .init("e5")!: .init(color: .white, figure: .king),
      .init("e8")!: .init(color: .black, figure: .king),
      .init("e7")!: .init(color: .white, figure: .pawn)
    ]))
    try game.move("Ke6")
    print(game)
    XCTAssertTrue(game.isGameOver)
  }
}
