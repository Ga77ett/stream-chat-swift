//
// Copyright © 2020 Stream.io Inc. All rights reserved.
//

import Combine
import CoreData
@testable import StreamChatClient
import XCTest

@available(iOS 13, *)
class CurrentUserController_Combine_Tests: iOS13TestCase {
    var currentUserController: CurrentUserControllerMock!
    var cancellables: Set<AnyCancellable>!

    override func setUp() {
        super.setUp()
        currentUserController = CurrentUserControllerMock()
        cancellables = []
    }
    
    override func tearDown() {
        // Release existing subscriptions and make sure the controller gets released, too
        cancellables = nil
        AssertAsync.canBeReleased(&currentUserController)
        super.tearDown()
    }
    
    func test_startUpdatingIsCalled_whenPublisherIsAccessed() {
        assert(currentUserController.startUpdating_called == false)
        _ = currentUserController.statePublisher
        XCTAssertTrue(currentUserController.startUpdating_called)
    }
    
    func test_statePublisher() {
        // Setup Recording publishers
        var recording = Record<DataController.State, Never>.Recording()
        
        // Setup the chain
        currentUserController
            .statePublisher
            .sink(receiveValue: { recording.receive($0) })
            .store(in: &cancellables)
        
        // Keep only the weak reference to the controller. The existing publisher should keep it alive.
        weak var controller: CurrentUserControllerMock? = currentUserController
        currentUserController = nil
        
        controller?.delegateCallback { $0.controller(controller!, didChangeState: .localDataFetched) }
        controller?.delegateCallback { $0.controller(controller!, didChangeState: .remoteDataFetched) }
        
        XCTAssertEqual(recording.output, [.initialized, .localDataFetched, .remoteDataFetched])
    }

    func test_currentUserChangePublisher() {
        // Setup Recording publishers
        var recording = Record<EntityChange<CurrentChatUser>, Never>.Recording()
        
        // Setup the chain
        currentUserController
            .currentUserChangePublisher
            .sink(receiveValue: { recording.receive($0) })
            .store(in: &cancellables)
        
        // Keep only the weak reference to the controller. The existing publisher should keep it alive.
        weak var controller: CurrentUserControllerMock? = currentUserController
        currentUserController = nil

        let newCurrentUser: CurrentChatUser = .init(id: .unique)
        controller?.currentUser_simulated = newCurrentUser
        controller?.delegateCallback {
            $0.currentUserController(controller!, didChangeCurrentUser: .create(newCurrentUser))
        }
        
        XCTAssertEqual(recording.output, [.create(newCurrentUser)])
    }
    
    func test_unreadCountPublisher() {
        // Setup Recording publishers
        var recording = Record<UnreadCount, Never>.Recording()
        
        // Setup the chain
        currentUserController
            .unreadCountPublisher
            .sink(receiveValue: { recording.receive($0) })
            .store(in: &cancellables)
        
        // Keep only the weak reference to the controller. The existing publisher should keep it alive.
        weak var controller: CurrentUserControllerMock? = currentUserController
        currentUserController = nil

        let newUnreadCount: UnreadCount = .dummy
        controller?.unreadCount_simulated = newUnreadCount
        controller?.delegateCallback {
            $0.currentUserController(controller!, didChangeCurrentUserUnreadCount: newUnreadCount)
        }
        
        XCTAssertEqual(recording.output, [.noUnread, .dummy])
    }
    
    func test_connectionStatusPublisher() throws {
        // Setup Recording publishers
        var recording = Record<ConnectionStatus, Never>.Recording()
        
        // Setup the chain
        currentUserController.connectionStatusPublisher
            .sink(receiveValue: { recording.receive($0) })
            .store(in: &cancellables)
        
        // Keep only the weak reference to the controller. The existing publisher should keep it alive.
        weak var controller: CurrentUserControllerMock? = currentUserController
        currentUserController = nil
        
        // Simulate connection status update
        let newStatus: ConnectionStatus = .connected
        controller?.delegateCallback { $0.currentUserController(controller!, didUpdateConnectionStatus: newStatus) }
        
        // Assert initial value as well as the update are received
        AssertAsync.willBeEqual(recording.output, [.disconnected(error: nil), newStatus])
    }
}
