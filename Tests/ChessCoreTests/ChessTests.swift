import XCTest
@testable import ChessCore

final class ChessTests: XCTestCase {
  private let twoRooksOnOneFileBoard: Game.Board = [
    Square(file: .a, rank: .one): Piece(color: .white, figure: .rook),
    Square(file: .a, rank: .eight): Piece(color: .white, figure: .rook)
  ]

  private let twoRooksOnOneRankBoard: Game.Board = [
    Square(file: .a, rank: .one): Piece(color: .white, figure: .rook),
    Square(file: .h, rank: .one): Piece(color: .white, figure: .rook)
  ]

  func testFoolsMate() throws {
    var game = Game()
    try game.move("f3")
    print(game)

    try game.move("e6")
    print(game)
    try game.move("g4")
    print(game)
    try game.move("Qh4#")
    print(game)

    XCTAssertEqual(game.victor, .black)
  }

  func testZ() throws {
    var game = Game(board: twoRooksOnOneRankBoard)
    XCTAssertThrowsError(try game.move("Rd1"))
    print(game)
  }

  func testOne() throws {
    var game = Game(board: twoRooksOnOneRankBoard)
    try game.move("Rad1")
    print(game)
  }

  func testTwo() throws {
    var game = Game(board: twoRooksOnOneRankBoard)
    try game.move("Rhe1")
    print(game)
  }

  // R1a4
  // R8a5
}
