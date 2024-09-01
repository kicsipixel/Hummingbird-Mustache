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
        router.get("/park/:id", use: self.show)
        router.get("/park/create", use: self.create)
        router.post("/park/create", use: self.createPost)
    }
    
    @Sendable func index(request: Request, context: some RequestContext) async throws -> HTML {
        let parks = try await Park.query(on: self.fluent.db()).all()
        
        let parkContext = parks.map { park in
            ParkContext(id: park.id,
                        name: park.name,
                        coordinates: ParkContext.Coordinates(latitude: park.coordinates.latitude,
                                                             longitude: park.coordinates.longitude))
        }
        
        let context = IndexContext(title: "Home page",
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
        
        let parkContext = ParkContext(id: park.id,
                                      name: park.name,
                                      coordinates: ParkContext.Coordinates(latitude: park.coordinates.latitude,
                                                                           longitude: park.coordinates.longitude))
        
        let context = ShowContext(title: park.name,
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
        let context = CreateContext(title: "Add a new park")
        
        guard let html = self.mustacheLibrary.render(context, withTemplate: "create") else {
            throw HTTPError(.internalServerError, message: "Failed to render template.")
        }
        return HTML(html: html)
    }
    
    /// This will be renamed or deleted...
    @Sendable func test(request: Request, context: some RequestContext) async throws -> HTML {
        let id = try context.parameters.require("id", as: UUID.self)
        guard let park = try await Park.find(id, on: self.fluent.db()) else {
            throw HTTPError(.notFound, message: "Park was not found")
        }
        
        let context = TestContext(park: park)
        
        guard let html = self.mustacheLibrary.render(context, withTemplate: "test") else {
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

struct ParkContext: Codable {
    let id: UUID?
    let name: String
    let coordinates: Coordinates
    
    struct Coordinates: Codable {
        let latitude: Double
        let longitude: Double
    }
}

struct TestContext: Codable {
    let park: Park
}
