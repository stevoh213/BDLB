import Foundation

/// GraphQL query definitions for OpenBeta
enum OpenBetaQueries {
    static func searchAreas(query: String, limit: Int) -> String {
        """
        query SearchAreas {
          areas(filter: { area_name: { contains: "\(query)" } }, first: \(limit)) {
            id
            areaName
            pathTokens
            totalClimbs
          }
        }
        """
    }

    static func searchClimbs(areaId: String, query: String?, limit: Int) -> String {
        let filterClause = query.map { "filter: { name: { contains: \"\($0)\" } }, " } ?? ""

        return """
        query SearchClimbs {
          area(id: "\(areaId)") {
            climbs(\(filterClause)first: \(limit)) {
              id
              name
              grades {
                vscale
                yds
                french
              }
              type {
                boulder
                sport
                trad
                tr
              }
            }
          }
        }
        """
    }

    static func getClimbDetails(climbId: String) -> String {
        """
        query GetClimbDetails {
          climb(id: "\(climbId)") {
            id
            name
            grades {
              vscale
              yds
              french
              uiaa
            }
            type {
              boulder
              sport
              trad
              tr
            }
            fa
            description
            location
            protection
          }
        }
        """
    }

    static func getAreaDetails(areaId: String) -> String {
        """
        query GetAreaDetails {
          area(id: "\(areaId)") {
            id
            areaName
            pathTokens
            totalClimbs
            metadata {
              lat
              lng
            }
            content {
              description
            }
          }
        }
        """
    }
}
