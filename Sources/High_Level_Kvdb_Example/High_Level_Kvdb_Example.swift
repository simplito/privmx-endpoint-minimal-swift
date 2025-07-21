// PrivMX Endpoint Minimal Swift
// Copyright © 2024 Simplito sp. z o.o.
//
// This file is project demonstrating usage of PrivMX Platform (https://privmx.dev).
// This software is Licensed under the MIT License.
//
// PrivMX Endpoint and PrivMX Bridge are licensed under the PrivMX Free License.
// See the License for the specific language governing permissions and
// limitations under the License.
//

import Foundation
import PrivMXEndpointSwift
import PrivMXEndpointSwiftExtra
import PrivMXEndpointSwiftNative

@main
struct High_Level_Kvdb_Example{
	public static func main() async throws{
		
		typealias UserWithPubKey = privmx.endpoint.core.UserWithPubKey  //for brevity
		typealias PagingQuery = privmx.endpoint.core.PagingQuery  //for brevity
		
		print("High-Level KVDB Example")
		
		// This example assumes that the bridge is hosted locally, which removes the necessity of setting ssl certificates
		// in a real-world scenario a certificate that will be used by OpenSSL for the connection needs to be provided.
		// let certPath = "/Path/to/the/certificate.file"
		
		// You can set the certificate either by calling
		// .setCertsPath(_:) on an instance of PrivMXEndpointContainer
		// or by calling
		// try Connection.setCertsPath(certPath)
		
		// In this example we assume that a context already exists
		// and a user (whose private key is used for connection) has been added to it
		let userId = "YourUserIDGoesHere"
		let userPK = "PrivateKeyOfTheUserInWIFFormatGoesHere"
		let solutionID = "TheIdOfYourSolutionGoesHere"
		let bridgeURL = "Address.Of.The.Bridge:GoesHere"
		let contextId = "TheIdOfYourContextGoesHere"
		
		// We create an instance of PrivMXEndpoint.
		// In a real-world scenario you'd be using a PrivMXEndpointContainer to manage PrivMXEndpoints as well as handle the event loop,
		// but since we aren't concerned with real time updates or multiple connections in this example,
		// instancing this class directly will suffice.
		guard
			var endpoint = try? PrivMXEndpoint.init(
				modules: [.kvdb],
				userPrivKey: userPK,
				solutionId: solutionID,
				bridgeUrl: bridgeURL)
		else { exit(1) }
		
		// To create a new Kvdb, a list of Users with their Public Keys is needed.
		// Thus we create one that will be used for both users and managers
		// (typically those lists won't be identical)
		var usersWithPublicKeys = [privmx.endpoint.core.UserWithPubKey]()
		
		// We add the current user to the list (in real world it should be a list of all participants).
		// The public key in this particular case can be derived from the private key,
		// but in typical circumstance should be acquired from an outside source (like your authorisation server)
		usersWithPublicKeys.append(
			UserWithPubKey(
				userId: std.string(userId),
				pubKey: try! CryptoApi.create().derivePublicKey(privKey: std.string(userPK))))
		
		let publicMeta = Data()
		let privateMeta = Data("My Example Kvdb".utf8)
		guard var kvdbApi = endpoint.kvdbApi
		else { exit(2) }
		
		// Next, we use the list as both a list of users and a list of managers to create a Kvdb
		// passing "My Example Kvdb" as its private metadata.
		// The method also returns the kvdbId of newly created Kvdb.
		// The nil Policies mean that the default value will be used.
		guard
			let kvdbId = try? kvdbApi.createKvdb(
				in: contextId,
				for: usersWithPublicKeys,
				managedBy: usersWithPublicKeys,
				withPublicMeta: publicMeta,
				withPrivateMeta: privateMeta,
				withPolicies: nil)
		else { exit(4) }
		
		// Now we list already present Entries, as a way of showcasing the difference later on,
		// since there will be none, at this point.
		guard
			let entries = try? kvdbApi.listEntries(
				from: kvdbId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc))
		else { exit(5) }
		
		print("--------")  //separator
		
		for e in entries.readItems {
			print(e, e.id, e.data)
		}
		
		// Entry can contain arbitrary data, but for this example we'll send just text.
		let exampleValue = Data("test value data, set @ \(Date.now)".utf8)
		
		
		// Entries are created for a particular pair of KVDB and key, where key acts as an identifier within that Kvdb.
		let entryKey = "example"
		try? kvdbApi.setEntry(
			in: kvdbId,
			for: entryKey,
			withPublicMeta: Data(),
			withPrivateMeta: Data(),
			containing: exampleValue)
		
		guard
			let entries2 = try? kvdbApi.listEntries(
				from: kvdbId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc))
		else { exit(7) }
		
		print("--------")  //separator
		
		for m2 in entries2.readItems {
			print(m2, m2.id, m2.data.getString() ?? "[Message was NIL]")
		}
		
		print("---- update -----")
		
		let updatedValue =
		"Old value was \"\(String(decoding:exampleValue,as:UTF8.self))\", now it's this @ \(Date.now) !"
		guard let updatedValueAsBuffer = updatedValue.data(using: .utf8) else { exit(1) }
		
		try! kvdbApi.setEntry(
			in:kvdbId,
			for: entryKey,
			atVersion: 1,
			withPublicMeta: Data(),
			withPrivateMeta: Data(),
			containing: updatedValueAsBuffer)
		
		//now we retrieve the new list of entries, which includes the newly updated message.
		guard
			let entriesList2 = try? kvdbApi.listEntries(
				from: kvdbId,
				basedOn: PagingQuery(
					skip: 0,
					limit: 10,
					sortOrder: .desc
				))
		else { exit(1) }
		
		// and print out the entries we retrieved
		for m in entriesList2.readItems {
			print(m.info.key, m.data.getString() ?? "")
		}
	}
}
