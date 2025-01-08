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
    let game = Game()
    try ["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6"].forEach(game.move)

    XCTAssertThrowsError(try game.move("Qxf7")) { error in
      guard case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "#" else {
        XCTFail("Expected .badPunctuation with correctPunctuation == \"#\", but got \(error).")
        return
      }
    }

    XCTAssertThrowsError(try game.move("Qxf7+")) { error in
      guard case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "#" else {
        XCTFail("Expected .badPunctuation with correctPunctuation == \"#\", but got \(error).")
        return
      }
    }

    try game.move("Qxf7#")

    XCTAssertTrue(game.isGameOver)
    guard case let .winner(color, isByResignation) = game.status, color == .white, !isByResignation else {
      XCTFail("Expected game.status to be .winner with color == .white and isByResignation == false, but got \(game.status).")
      return
    }
  }

  func testStalemate() throws {
    let game = Game(board: [
      .init("e5")!: .init(color: .white, figure: .king),
      .init("e8")!: .init(color: .black, figure: .king),
      .init("e7")!: .init(color: .white, figure: .pawn)
    ])

    XCTAssertThrowsError(try game.move("Ke6+")) { error in
      guard case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "" else {
        XCTFail("Expected .badPunctuation with correctPunctuation == \"\", but got \(error).")
        return
      }
    }

    XCTAssertThrowsError(try game.move("Ke6#")) { error in
      guard case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "" else {
        XCTFail("Expected .badPunctuation with correctPunctuation == \"\", but got \(error).")
        return
      }
    }

    try game.move("Ke6")

    XCTAssertTrue(game.isGameOver)
    guard case let .draw(isStalemate) = game.status else {
      XCTFail("Expected game.status to be .draw with stalemate == true, but got \(game.status).")
      return
    }
  }
}
