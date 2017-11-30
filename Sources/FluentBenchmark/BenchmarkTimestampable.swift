import Async
import Dispatch
import Fluent
import Foundation

extension Benchmarker {
    /// The actual benchmark.
    fileprivate func _benchmark(on conn: Database.Connection) throws -> Future<Void> {
        // create
        let tanner = User<Database>(name: "Tanner", age: 23)
        if tanner.createdAt != nil || tanner.updatedAt != nil {
            self.fail("timestamps should have been nil")
        }

        return tanner.save(on: conn).then { _ -> Future<Date> in
            if tanner.createdAt?.isWithin(seconds: 1, of: Date()) != true {
                self.fail("timestamps should be current")
            }
            
            if tanner.updatedAt?.isWithin(seconds: 1, of: Date()) != true {
                self.fail("timestamps should be current")
            }
            
            return tanner.save(on: conn).map {
                return tanner.updatedAt!
            }
        }.then { originalUpdatedAt -> Future<User<Database>?> in
            if tanner.updatedAt! <= originalUpdatedAt {
                self.fail("new updated at should be greater")
            }
            
            return try conn.query(User<Database>.self).filter(\User<Database>.name == "Tanner").first()
        }.map { fetched in
            guard let fetched = fetched else {
                self.fail("could not fetch user")
                return
            }
            
            // microsecond roudning
            if !fetched.createdAt!.isWithin(seconds: 2, of: tanner.createdAt!) && !fetched.updatedAt!.isWithin(seconds: 2, of: tanner.updatedAt!) {
                self.fail("fetched timestamps are different")
            }
        }
    }

    /// Benchmark the Timestampable protocol
    public func benchmarkTimestampable() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return try self._benchmark(on: conn).map {
                self.pool.releaseConnection(conn)
            }
        }
    }
}

extension Benchmarker where Database.Connection: SchemaSupporting {
    /// Benchmark the Timestampable protocol
    /// The schema will be prepared first.
    public func benchmarkTimestampable_withSchema() throws -> Future<Void> {
        return pool.requestConnection().then { conn in
            return UserMigration<Database>.prepare(on: conn).then { _ in
                return try self._benchmark(on: conn).map { _ in
                    self.pool.releaseConnection(conn)
                }
            }
        }
    }
}

extension Date {
    public func isWithin(seconds: Double, of other: Date) -> Bool {
        var diff = other.timeIntervalSince1970 - self.timeIntervalSince1970
        if diff < 0 {
            diff = diff * -1.0
        }
        return diff <= seconds
    }

    public var unix: Int {
        return Int(timeIntervalSince1970)
    }
}
