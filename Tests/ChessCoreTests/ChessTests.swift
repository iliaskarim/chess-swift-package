import XCTest
@testable import ChessCore

final class ChessTests: XCTestCase {
  func testFirstMoves() throws {
    let game = Game()

    XCTAssertEqual(Set(game.board.moves(from: .init(notation: "b1")!)), Set([.init(notation: "a3")!, .init(notation: "c3")!]))
    XCTAssertEqual(Set(game.board.moves(from: .init(notation: "g1")!)), Set([.init(notation: "f3")!, .init(notation: "h3")!]))

    Square.File.allCases.forEach { file in
      XCTAssertEqual(Set(game.board.moves(from: .init(file: file, rank: .two))), Set([
        .init(file: file, rank: .three),
        .init(file: file, rank: .four)
      ]))
    }
  }

  func testScholarsMate() throws {
    let game = Game()
    try ["e4", "e5", "Qh5", "Nc6", "Bc4", "Nf6"].forEach(game.move)

    XCTAssertThrowsError(try game.move(notation: "Qxf7")) { error in
      if case let .badPunctuation(correctPunctuation) = error as? InvalidNotation {
        XCTAssertEqual(correctPunctuation, "#", "Expected correct punctuation to be \"#\"")
      } else {
        XCTAssert(false, "Expected error to be `InvalidNotation.badPunctuation`.")
      }
    }

    XCTAssertThrowsError(try game.move(notation: "Qxf7+")) { error in
      if case let .badPunctuation(correctPunctuation) = error as? InvalidNotation {
        XCTAssertEqual(correctPunctuation, "#", "Expected correct punctuation to be \"#\"")
      } else {
        XCTAssert(false, "Expected error to be `InvalidNotation.badPunctuation`.")
      }
    }

    try game.move(notation: "Qxf7#")

    XCTAssert(game.isGameOver, "Expected game to be over.")

    if case let .winner(color, isByResignation) = game.status {
      XCTAssertEqual(color, .white, "Expected color to be `.white`.")
      XCTAssert(!isByResignation, "Expected isByResignation to be false.")
    } else {
      XCTAssert(false, "Expected game status to be `.winner`.")
    }

    print(game)
  }

  func testStalemate() throws {
    let game = Game(board: [
      .init(notation: "e5")!: .init(color: .white, figure: .king),
      .init(notation: "e8")!: .init(color: .black, figure: .king),
      .init(notation: "e7")!: .init(color: .white, figure: .pawn)
    ])

    XCTAssertThrowsError(try game.move(notation: "Ke6+")) { error in
      if case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "" {
        XCTAssertEqual(correctPunctuation, "", "Expected correct punctuation to be \"\"")
      } else {
        XCTAssert(false, "Expected error to be `InvalidNotation.badPunctuation`.")
      }
    }

    XCTAssertThrowsError(try game.move(notation: "Ke6#")) { error in
      if case let .badPunctuation(correctPunctuation) = error as? InvalidNotation, correctPunctuation == "" {
        XCTAssertEqual(correctPunctuation, "", "Expected correct punctuation to be \"\"")
      } else {
        XCTAssert(false, "Expected error to be `InvalidNotation.badPunctuation`.")
      }
    }

    try game.move(notation: "Ke6")

    XCTAssert(game.isGameOver, "Expected game to be over.")

    if case let .draw(draw) = game.status {
      XCTAssert(draw == .byStalemate, "Expected draw to be `.byStalemate`.")
    } else {
      XCTAssert(false, "Expected game status to be `.draw`.")
    }

    print(game)
  }
}
