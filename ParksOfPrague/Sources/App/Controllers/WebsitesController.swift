import FluentKit
import Foundation
import Hummingbird
import HummingbirdFluent
import Mustache

struct HTML: ResponseGenerator {
  let html: String

  public func response(from request: Request, context: some RequestContext) throws -> Response {
    let buffer = ByteBuffer(string: self.html)
    return .init(status: .ok, headers: [.contentType: "text/html"], body: .init(byteBuffer: buffer))
  }
}

struct WebsitesController {

  let fluent: Fluent
  let mustacheLibrary: MustacheLibrary

  func addRoutes(to router: Router<some RequestContext>) {
    router.get("/", use: self.index)
    router.get("/parks/:id", use: self.show)
    router.get("/parks/create", use: self.create)
    router.post("/parks/create", use: self.createPost)
    router.get("/parks/:id/edit", use: self.edit)
    router.post("/parks/:id/edit", use: self.editPost)
    router.get("/parks/:id/delete", use: self.delete)
  }

  @Sendable func index(request: Request, context: some RequestContext) async throws -> HTML {
    let parks = try await Park.query(on: self.fluent.db()).all()

    let parkContext = parks.map { park in
      ParkContext(
        id: park.id,
        name: park.name,
        coordinates: ParkContext.Coordinates(
          latitude: park.coordinates.latitude,
          longitude: park.coordinates.longitude))
    }

    let context = IndexContext(
      title: "Home page",
      parkContexts: parkContext)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "index") else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func show(request: Request, context: some RequestContext) async throws -> HTML {
    let id = try context.parameters.require("id", as: UUID.self)
    guard let park = try await Park.find(id, on: self.fluent.db()) else {
      throw HTTPError(.notFound, message: "Park was not found")
    }

    let parkContext = ParkContext(
      id: park.id,
      name: park.name,
      coordinates: ParkContext.Coordinates(
        latitude: park.coordinates.latitude,
        longitude: park.coordinates.longitude))

    let context = ShowContext(
      title: park.name,
      parkContext: parkContext)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "show") else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func create(request: Request, context: some RequestContext) async throws -> HTML {
    let context = CreateContext(title: "Add a new park")

    guard let html = self.mustacheLibrary.render(context, withTemplate: "create") else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func createPost(request: Request, context: some RequestContext) async throws -> HTML {
    let data = try await request.decode(as: FormData.self, context: context)
    let park = Park(
      name: data.name, coordinates: Coordinates(latitude: data.latitude, longitude: data.longitude))

    /// Save to DB
    try await park.save(on: self.fluent.db())

    /// Show
    let parkContext = ParkContext(
      id: park.id,
      name: park.name,
      coordinates: ParkContext.Coordinates(
        latitude: park.coordinates.latitude,
        longitude: park.coordinates.longitude))
    let context = ShowContext(
      title: park.name,
      parkContext: parkContext)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "show") else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func edit(request: Request, context: some RequestContext) async throws -> HTML {
    let id = try context.parameters.require("id", as: UUID.self)
    guard let park = try await Park.find(id, on: self.fluent.db()) else {
      throw HTTPError(.notFound, message: "Park was not found")
    }

    let parkContext = ParkContext(
      id: park.id,
      name: park.name,
      coordinates: ParkContext.Coordinates(
        latitude: park.coordinates.latitude,
        longitude: park.coordinates.longitude))
    let context = EditContext(
      title: "Edit \(park.name)",
      parkContext: parkContext,
      isEditing: true)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "create", reload: true)
    else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func editPost(request: Request, context: some RequestContext) async throws -> HTML {
    let id = try context.parameters.require("id", as: UUID.self)
    guard let park = try await Park.find(id, on: self.fluent.db()) else {
      throw HTTPError(.notFound, message: "Park was not found")
    }

    let data = try await request.decode(as: FormData.self, context: context)

    park.name = data.name
    park.coordinates.latitude = data.latitude
    park.coordinates.longitude = data.longitude

    /// Save to DB
    try await park.save(on: self.fluent.db())

    let parkContext = ParkContext(
      id: park.id, name: park.name,
      coordinates: ParkContext.Coordinates(
        latitude: park.coordinates.latitude,
        longitude: park.coordinates.longitude))
    let context = ShowContext(
      title: park.name,
      parkContext: parkContext)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "show", reload: true) else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }

  @Sendable func delete(request: Request, context: some RequestContext) async throws -> HTML {
    let id = try context.parameters.require("id", as: UUID.self)
    guard let park = try await Park.find(id, on: fluent.db()) else {
      throw HTTPError(.notFound)
    }

    try await park.delete(on: self.fluent.db())

    let parkContext = ParkContext(
      id: park.id,
      name: park.name,
      coordinates: ParkContext.Coordinates(
        latitude: park.coordinates.latitude,
        longitude: park.coordinates.longitude))

    let context = ShowContext(
      title: park.name,
      parkContext: parkContext)

    guard let html = self.mustacheLibrary.render(context, withTemplate: "delete") else {
      throw HTTPError(.internalServerError, message: "Failed to render template.")
    }
    return HTML(html: html)
  }
}

/// Contexts
struct IndexContext: Codable {
  let title: String
  let parkContexts: [ParkContext]
}

struct ShowContext: Codable {
  let title: String
  let parkContext: ParkContext
}

struct CreateContext: Codable {
  let title: String
}

struct CreatePostContext: Codable {
  let title: String
  let park: Park
}

struct EditContext: Codable {
  let title: String
  let parkContext: ParkContext
  let isEditing: Bool
}

struct ParkContext: Codable {
  let id: UUID?
  let name: String
  let coordinates: Coordinates

  struct Coordinates: Codable {
    let latitude: Double
    let longitude: Double
  }
}

struct FormData: ResponseCodable {
  let name: String
  let latitude: Double
  let longitude: Double
}

struct SaveParkData: ResponseCodable {
  let name: String
  let coordinates: Coordinates

  struct CoordinatesData: Codable {
    let latitude: Double
    let longitude: Double
  }
}
