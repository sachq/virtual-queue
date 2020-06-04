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
    uint8 _yob;
    Status _status;
    uint32 _queueNumber;
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

  // To Track all requested Users
  mapping(address => Consumer) consumerMap;

  // To track _activeQueue (Queue) and Consumer
  // (store_address => (queue_number => consumer))
  // mapping(address => mapping(uint32 => Consumer)) storeQueueMap;

  struct Product {
    string _itemName;
    uint64 _price; // Save in eth
    bool _isAvailable;
  }

  // Global Variables
  uint8 MAX_QUEUE = 3;

  // Manages Stores
  address payable manager;

  // Waiting-list queue and Registered Users List
  Queue private waitingQueue;
  mapping(uint32 => Consumer) waitingQueueMap;
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
    stores[totalStores] = Store(
      _storeAddress,
      _storeName,
      new Queue(),
      0,
      true
    );
    totalStores += 1;
  }

  // Request Queue: User requests for a queue
  function requestQueue(uint8 _yearOfBirth) public {
    // Check If User is already in any Queue
    require(canRegisterUser(msg.sender), "Already in Queue");

    // Check If User has minimum age of 18
    require(_yearOfBirth <= 2002, "Not Eligible");

    // Check if atleast one Store is Available
    require(totalStores > 0, "No Store(s) Available to register");

    // Register User to the appropriate Queue
    (address shortQueueStore, uint32 queueLength) = registerToQueue();
    if (shortQueueStore == address(0)) {
      storeQueueMap[shortQueueStore][queueLength] = Consumer(
        _yearOfBirth,
        Status.Active,
        queueLength,
        shortQueueStore,
        true
      );
    } else {
      storeQueueMap[shortQueueStore][queueLength] = Consumer(
        _yearOfBirth,
        Status.Active,
        queueLength,
        shortQueueStore,
        true
      );
    }
  }

  // Finds the Store with the least Queue size
  function registerToQueue() private returns(address, uint32) {
    uint32 leastQueue = 0;
    uint32 storeIndex = 0;
    for (uint32 i = 0; i < totalStores; i++) {
      if (stores[i]._queueLength <= leastQueue) {
        leastQueue = stores[i]._queueLength;
        storeIndex = i;
      }
    }

    // Move Consumer to Waiting Queue if the Queue is full
    if (stores[storeIndex]._queueLength == MAX_QUEUE) {
      Consumer storage consumer = consumerMap[msg.sender];
      waitingQueue.enqueue(msg.sender);
      waitingQueueMap[waitingQueueLength + 1] = Consumer(
        consumer._yob,
        Status.Waiting,
        waitingQueueLength + 1,
        address(0),
        true
      );
      waitingQueueLength += 1;
      // Returns Waiting Queue
      return (address(0), waitingQueueLength);
    }

    // Queue length
    uint32 currentLength = stores[storeIndex]._queueLength;

    // Set the Queue Number as Key - Increment Queue Length by 1
    stores[storeIndex]._queueLength += 1;

    // Enqueue to Stores Active Queue
    stores[storeIndex]._activeQueue.enqueue(msg.sender);

    // Returns Store Queue
    return (stores[storeIndex]._address, currentLength);
  }

  // Buy from the alloted Store
  // & Transfer Amount to the Manager
  function buyProduct(uint32 productId) public payable returns(string memory, uint64) {
    address userAddress = msg.sender;
    Product storage product = products[productId];
    Consumer storage consumer = consumerMap[userAddress];
    require(consumerMap[userAddress]._isAuthorised, "User is not Authorized");
    require(product._isAvailable, "Product is not Available");
    require(consumerMap[userAddress]._status == Status.Active, "Not in Queue");
    require(consumerMap[userAddress]._queueNumber == 1, "Wait for your Queue");
    require(msg.value == product._price, "Price not met");

    // Transfer AMOUNT to Manager
    manager.transfer(msg.value);

    // Reset Consumer with Default values;
    // Reset Store Address as the consumer
    // is not associated to any store after buying
    consumerMap[userAddress] = Consumer(
      consumer._yob,
      Status.Idle,
      0,
      address(0), // Store address
      consumer._isAuthorised
    );

    return (product._itemName, product._price);
  }

  // Check If Consumer Already exist in any Queue
  function canRegisterUser(address userAddress) private view returns(bool) {
    if (consumerMap[userAddress]._status == Status.Idle ) return true;
    return false;
  }

}