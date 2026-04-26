import XCTest
@testable import DeuxOrders

final class DeuxOrdersTests: XCTestCase {
    func testProductResponseDecodesIntegerCentPriceAndDefaultsRecipeFlag() throws {
        let json = """
        {
          "id": "product-1",
          "name": "Naked Cake",
          "price": 2500,
          "status": true,
          "image": null,
          "description": "Bolo",
          "category": "Bolos",
          "size": "M"
        }
        """.data(using: .utf8)!

        let product = try JSONDecoder().decode(ProductResponse.self, from: json)

        XCTAssertEqual(product.price, 2500)
        XCTAssertFalse(product.hasRecipe)
        XCTAssertEqual(product.description, "Bolo")
        XCTAssertEqual(product.size, "M")
    }

    func testProductListDecodesPaginatedAndArrayShapes() throws {
        let paginated = """
        {
          "items": [
            { "id": "product-1", "name": "Bolo", "price": 1500, "status": true }
          ],
          "totalCount": 1,
          "pageNumber": 1,
          "pageSize": 100
        }
        """.data(using: .utf8)!

        let array = """
        [
          { "id": "product-2", "name": "Cookie", "price": 900, "status": true }
        ]
        """.data(using: .utf8)!

        XCTAssertEqual(try JSONDecoder().decode(ProductListResponse.self, from: paginated).items.first?.id, "product-1")
        XCTAssertEqual(try JSONDecoder().decode(ProductListResponse.self, from: array).items.first?.id, "product-2")
    }

    func testOrderInputEncodesCanonicalDeliveryKey() throws {
        let input = OrderInput(
            clientId: "client-1",
            deliveryDate: "2026-04-25T14:30:00Z",
            deliveryAddress: "pickup",
            items: [
                OrderItemInput(
                    productId: "product-1",
                    quantity: 2,
                    unitPrice: 0,
                    observation: nil,
                    massa: nil,
                    sabor: nil
                )
            ],
            references: ["order-references/ref.jpg"]
        )

        let object = try JSONSerialization.jsonObject(with: JSONEncoder().encode(input)) as? [String: Any]

        XCTAssertEqual(object?["clientId"] as? String, "client-1")
        XCTAssertEqual(object?["delivery"] as? String, "pickup")
        XCTAssertNil(object?["deliveryAddress"])
        XCTAssertEqual((object?["items"] as? [[String: Any]])?.first?["unitPrice"] as? Int, 0)
    }

    func testOrderDecodesDeliveryAndLegacyDeliveryAddress() throws {
        let canonical = makeOrderJSON(deliveryField: "\"delivery\": \"pickup\"")
        let legacy = makeOrderJSON(deliveryField: "\"deliveryAddress\": \"Rua X, 123\"")

        XCTAssertEqual(try APIClient.dateDecoder.decode(Order.self, from: canonical).deliveryAddress, "pickup")
        XCTAssertEqual(try APIClient.dateDecoder.decode(Order.self, from: legacy).deliveryAddress, "Rua X, 123")
    }

    func testMeasureUnitDecodesStringAndNumericAndEncodesNumeric() throws {
        XCTAssertEqual(try JSONDecoder().decode(MeasureUnit.self, from: "\"G\"".data(using: .utf8)!), .g)
        XCTAssertEqual(try JSONDecoder().decode(MeasureUnit.self, from: "1".data(using: .utf8)!), .ml)
        XCTAssertEqual(String(data: try JSONEncoder().encode(MeasureUnit.u), encoding: .utf8), "3")
    }

    func testUpdateOrderResultDecodesWrappedWarnings() throws {
        let json = """
        {
          "response": {
            "id": "order-1",
            "deliveryDate": "2026-04-25T14:30:00Z",
            "status": "Preparing",
            "clientId": "client-1",
            "clientName": "Maria",
            "totalPaid": 0,
            "totalValue": 0,
            "items": [],
            "references": []
          },
          "warnings": ["Estoque insuficiente"]
        }
        """.data(using: .utf8)!

        let result = try APIClient.dateDecoder.decode(UpdateOrderResult.self, from: json)

        XCTAssertEqual(result.order.status, .preparing)
        XCTAssertEqual(result.warnings, ["Estoque insuficiente"])
    }

    func testLocalDayBoundsUseStartAndExclusiveEnd() {
        var components = DateComponents()
        components.calendar = Calendar(identifier: .gregorian)
        components.timeZone = TimeZone(identifier: "America/Sao_Paulo")
        components.year = 2026
        components.month = 4
        components.day = 25
        components.hour = 14
        let date = components.date!

        XCTAssertTrue(Formatters.utcISOForStartOfLocalDay(date).contains("T03:00:00Z"))
        XCTAssertTrue(Formatters.utcISOForExclusiveEndOfLocalDay(date).contains("T03:00:00Z"))
        XCTAssertNotEqual(Formatters.utcISOForStartOfLocalDay(date), Formatters.utcISOForExclusiveEndOfLocalDay(date))
    }

    private func makeOrderJSON(deliveryField: String) -> Data {
        """
        {
          "id": "order-1",
          "deliveryDate": "2026-04-25T14:30:00Z",
          "status": "Received",
          "clientId": "client-1",
          "clientName": "Maria",
          "totalPaid": 0,
          "totalValue": 0,
          "items": [],
          "references": [],
          \(deliveryField),
          "paidAt": null,
          "paidByUserName": null
        }
        """.data(using: .utf8)!
    }
}
