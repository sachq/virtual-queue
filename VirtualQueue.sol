// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

import { Queue } from "./Queue.sol";

contract VirtualQueue {

  enum Status {
    Idle,
    Active,
    Waiting
  }

  // Consumer who buys an Product from the Store
  struct Consumer {
    string _name;
    uint8 _yob;
    Status _status;
    address _storeAddres;
    bool _isAuthorised;
  }

  // Consumer who buys an Product from the Store
  struct Store {
    address _address;
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
  mapping(address => address) firstConsumerMap;

  // Waiting-list queue and Registered Users List
  Queue private waitingQueue;
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
  constructor(address payable _manager) public {
    manager = _manager;
  }

  // Add new Product to the Store
  function addProduct(string memory _productName, uint64 _productPrice) public onlyManager {
    products[totalProducts] = Product(
      _productName,
      _productPrice * 1000000000000000000,
      true
    );
    totalProducts += 1;
  }

  // Add new Product to the Store
  function updateProduct(uint32 index, string memory _productName, uint64 _productPrice) public onlyManager {
    products[index] = Product(
      _productName,
      _productPrice * 1000000000000000000,
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
    if (stores[totalStores]._isActive) return;
    totalStores += 1;
    stores[totalStores] = Store(
      _storeAddress,
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

  // Find the Index of the Store with shortest queue
  function findShortestQueue() private view returns(uint32) {
    uint32 leastQueue = 0;
    uint32 storeIndex = 0;
    for (uint32 i = 1; i <= totalStores; i++) {
      if (stores[i]._queueLength <= leastQueue) {
        leastQueue = stores[i]._queueLength;
        storeIndex = i;
      }
    }
    return storeIndex;
  }

  // Request Queue: User requests for a queue
  function requestQueue(string memory _name, uint8 _yearOfBirth) public {
    // Check If User is already in any Queue
    require(canRegisterUser(msg.sender), "Already in Queue");

    // Check If User has minimum age of 18
    require(_yearOfBirth <= 2002, "Not Eligible");

    // Check atleast one Store is Available
    require(totalStores > 0, "No Store(s) Available to register");

    // Register User to the appropriate Queue
    // Store Active-Queue / Waiting-Queue
    (address storeAddress, uint32 queueLength, Status status) = registerToQueue();

    // Set Consumer with Store-level data (storeAddress and queueNumber)
    // Queue number based on the Queue (Active/Waiting)
    consumerMap[msg.sender] = Consumer(
      _name,
      _yearOfBirth,
      status,
      storeAddress,
      true
    );

    // Set Consumer Address as First In Queue
    // for a Store if QueueLength is Only 1
    if (status == Status.Active && queueLength == 1) {
      firstConsumerMap[storeAddress] = msg.sender;
    }
  }

  // Finds the Store with the least Queue size
  function registerToQueue() private returns(address, uint32, Status) {
    uint32 storeIndex = findShortestQueue(); // Find shortest queue
    Store memory store = stores[storeIndex];

    // Move Consumer to Waiting Queue if the Queue is full
    if (store._queueLength == MAX_QUEUE) {
      waitingQueue.enqueue(msg.sender);
      waitingQueueLength += 1;
      return (address(0), waitingQueueLength, Status.Waiting);
    }

    // Enqueue to Stores Active Queue
    store._activeQueue.enqueue(msg.sender);

    // Set the Queue Number as Key - Increment Queue Length by 1
    stores[storeIndex]._queueLength += 1;
    return (store._address, stores[storeIndex]._queueLength, Status.Active);
  }

  // Buy Product from the assigned Store
  // & Transfer Amount to the Manager
  function buyProduct(
    uint32 storeId,
    uint32 productId
  ) public
    payable
    returns (string memory, uint64) {
    address userAddress = msg.sender;

    Product memory product = products[productId];
    Store memory selectedStore = stores[storeId];
    Consumer memory consumer = consumerMap[userAddress];

    require(consumer._isAuthorised, "User is not Authorized");
    require(product._isAvailable, "Product is not Available");
    require(consumer._status == Status.Active, "Not in Queue");
    require(userAddress == firstConsumerMap[selectedStore._address], "Yet to be served");
    require(msg.value == product._price, "Price not met");

    // Transfer AMOUNT to Manager
    manager.transfer(msg.value);

    // Reset Consumer with Default values;
    // Reset Store Address as the consumer
    // is not associated to any store after buying
    consumerMap[userAddress]._status = Status.Idle;
    consumerMap[userAddress]._storeAddres = address(0);

    /* Manage Waiting and Active Store Queue */

    // Dequeue Consumer from Active Queue Set as First Consumer
    if (stores[storeId]._queueLength > 0) {
      address nextUserAddress = stores[storeId]._activeQueue.dequeue();
      stores[storeId]._queueLength -= 1;
      firstConsumerMap[selectedStore._address] = nextUserAddress;
    }

    // If there is waiting consumers in the Waiting Queue
    if (waitingQueueLength > 0) {
      address waitingUserAddress = waitingQueue.dequeue();
      uint32 shortQueueStoreId = findShortestQueue();
      // Move last Waiting User to stores with the shortest queue
      stores[shortQueueStoreId]._activeQueue.enqueue(waitingUserAddress);
      stores[shortQueueStoreId]._queueLength += 1;
      waitingQueueLength -= 1;
    }

    return (product._itemName, product._price);
  }

  // Check If Consumer Already exist in any Queue
  function canRegisterUser(address userAddress) private view returns(bool) {
    if (consumerMap[userAddress]._status == Status.Idle ) return true;
    return false;
  }

}