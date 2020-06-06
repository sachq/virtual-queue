// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;
pragma experimental ABIEncoderV2;

import { Queue } from './Queue.sol';

contract VirtualQueue {
  enum Status {
    Idle,
    Active,
    Waiting
  }

  // Consumer who buys an Product from the Store
  struct Consumer {
    Status _status;
    address _storeAddres;
    bool _isAuthorised;
  }

  // Consumer who buys an Product from the Store
  struct Store {
    address _address;
    address _nextInQueue;
    string _storeName;
    Queue _activeQueue;
    uint8 _queueLength;
    bool _isActive;
  }

  struct Product {
    string _itemName;
    uint64 _price; // Save in eth
    bool _isAvailable;
  }

  // Global Variables
  uint8 MAX_QUEUE = 3;

  // All Registered Consumers
  mapping(address => Consumer) consumerMap;

  // Manages Stores
  address payable manager;

  // Store address => Consumer address - First in Queue
  // mapping(address => address) firstConsumerMap;

  // Waiting-list queue and Registered Users List
  Queue private waitingQueue = new Queue();
  uint8 waitingQueueLength = 0;

  // General Store Items
  mapping(uint32 => Product) public products;
  uint32 totalProducts = 0;

  // Registered Stores by the Manager
  mapping(uint32 => Store) public stores;
  uint32 totalStores = 0;

  // Actions ONLY Managers can perform:
  // registerStore, addItem, removeItem
  modifier onlyManager() {
    require(
      manager == msg.sender,
      "Only Manager is allowed to do this operation!"
    );
    _;
  }

  // Deploy with Manager's Address
  constructor() public {
    manager = msg.sender;
  }

  // Add new Product to the Store
  function addProduct(string memory _productName, uint64 _productPrice) public onlyManager {
    totalProducts += 1;
    products[totalProducts] = Product(
      _productName,
      _productPrice * 1 ether,
      true
    );
  }

  // Add new Product to the Store
  function updateProduct(uint32 index, string memory _productName, uint64 _productPrice) public onlyManager {
    products[index] = Product(
      _productName,
      _productPrice * 1 ether,
      true
    );
  }

  // Disable Product at Index
  function disableProduct(uint32 index) public onlyManager {
    products[index]._isAvailable = false;
  }

  // Register new Store for Manager
  function registerStore(address _storeAddress, string memory _storeName) public onlyManager {
    // Do nothing if Store is Available
    // if (stores[totalStores]._isActive) return;
    totalStores += 1;
    stores[totalStores] = Store(
      _storeAddress,
      address(0),
      _storeName,
      new Queue(),
      0,
      true
    );
  }

  // Disable Store at Index
  function disableStore(uint32 index) public onlyManager {
    stores[index]._isActive = false;
  }

  function viewConsumer() public view returns(Consumer memory) {
    return consumerMap[msg.sender];
  }

  function totalWaiting() public view returns(uint32) {
    return waitingQueueLength;
  }

  // Request Queue: User requests for a queue
  function requestQueue() public returns (uint32, uint32) {
    // Check If User is already in any Queue
    require(canRegisterUser(msg.sender), "Already in Queue");

    // Check atleast one Store is Available
    require(totalStores > 0, "No Store(s) Available to register");

    // Register User to the appropriate Queue
    // Store Active-Queue / Waiting-Queue
    (
      address storeAddress,
      uint32 queueLength,
      uint32 storeIndex,
      Status status
    ) = registerToQueue();

    // Set Consumer with Store-level data (storeAddress and queueNumber)
    // Queue number based on the Queue (Active/Waiting)
    consumerMap[msg.sender] = Consumer(
      status,
      storeAddress,
      true
    );

    // Set Consumer Address as First In Queue
    // for a Store if QueueLength is Only 1
    if (status == Status.Active && queueLength == 1) {
      stores[storeIndex]._nextInQueue = msg.sender;
      stores[storeIndex]._activeQueue.dequeue();
    }

    // Return Store Index and its Queue length
    return (storeIndex, queueLength);
  }

  // Finds the Store with the least Queue size
  function registerToQueue() private returns(address, uint32, uint32, Status) {
    uint32 storeIndex = findShortestQueue(); // Find shortest queue
    Store memory store = stores[storeIndex];

    // Move Consumer to Waiting Queue if the Queue is full
    if (store._queueLength == MAX_QUEUE) {
      waitingQueue.enqueue(msg.sender);
      waitingQueueLength += 1;
      return (address(0), waitingQueueLength, storeIndex, Status.Waiting);
    }

    // Move user to Store Waiting Queue
    stores[storeIndex]._activeQueue.enqueue(msg.sender);
    stores[storeIndex]._queueLength += 1;
    return (store._address, stores[storeIndex]._queueLength, storeIndex, Status.Active);
  }

  // Find the Index of the Store with shortest queue
  function findShortestQueue() private view returns(uint32) {
    uint32 storeIndex = 1;
    for (uint32 i = storeIndex; i < totalStores; i++) {
      Store memory currentStore = stores[i];
      // Return the store index Queue is empty
      if (currentStore._queueLength == 0) {
        return i;
      } else if (stores[i + 1]._queueLength < currentStore._queueLength) {
        storeIndex = i + 1;
      }
    }
    return storeIndex;
  }

  // Check If Consumer Already exist in any Queue
  function canRegisterUser(address userAddress) private view returns(bool) {
    if (consumerMap[userAddress]._status == Status.Idle ) return true;
    return false;
  }

  // Buy Product from the assigned Store
  // & Transfer Amount to the Manager
  function buyProduct(
    uint32 storeId,
    uint32 productId
  ) public
    payable {
    address userAddress = msg.sender;

    Product memory product = products[productId];
    Store memory selectedStore = stores[storeId];
    Consumer memory consumer = consumerMap[userAddress];

    require(consumer._isAuthorised, "User is not Authorized");
    require(product._isAvailable, "Product is not Available");
    require(consumer._status == Status.Active, "Not in Queue");
    require(consumer._storeAddres == selectedStore._address, "Allotted a different Store");
    require(userAddress == stores[storeId]._nextInQueue, "Waiting in Queue");
    require(msg.value == product._price, "Price not met");

    // Reset Consumer with Default values;
    // Reset Store Address as the consumer
    // is not associated to any store after buying
    consumerMap[userAddress]._status = Status.Idle;
    consumerMap[userAddress]._storeAddres = address(0);

    // Tracking Active Queue Length (Store)
    // Decrement Queue length alone
    if (stores[storeId]._queueLength == 1) {
      stores[storeId]._queueLength -= 1;
    }

    // Dequeue Consumer from Active Queue Set as First Consumer
    if (stores[storeId]._queueLength > 1) {
      address nextUserAddress = stores[storeId]._activeQueue.dequeue();
      stores[storeId]._queueLength -= 1;
      stores[storeId]._nextInQueue = address(nextUserAddress);
    }

    // If there is waiting consumers in the Waiting Queue
    if (waitingQueueLength >= 1) {
      address waitingUserAddress = waitingQueue.dequeue();
      uint32 shortQueueStoreId = findShortestQueue();
      // Move last Waiting User to stores with the shortest queue
      stores[shortQueueStoreId]._activeQueue.enqueue(waitingUserAddress);
      consumerMap[waitingUserAddress]._storeAddres = stores[shortQueueStoreId]._address;
      consumerMap[waitingUserAddress]._status = Status.Active;
      stores[shortQueueStoreId]._queueLength += 1;
      waitingQueueLength -= 1;
    }

    // Transfer AMOUNT to Manager
    manager.transfer(msg.value);
  }

}