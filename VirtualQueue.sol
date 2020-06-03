// SPDX-License-Identifier: GPL-3.0
pragma solidity >=0.4.22 <0.7.0;

import { Queue } from "./Queue.sol";

contract VirtualQueue {

  // Consumer who buys an Product from the Store
  struct Consumer {
    address _address;
    uint8 _yob;
    address _activeStore;
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
  // To track _activeQueue (Queue) and Consumer
  mapping(address => mapping(uint32 => Consumer)) storeQueueMap;

  struct Product {
    string _itemName;
    uint64 _price; // Save in eth
    bool _isAvailable;
  }

  // Global Variables
  uint64 ONE_ETH = 1 ether;
  uint8 MAX_QUEUE = 3;

  // Manages Stores
  address manager;

  // Waiting-list queue and Registered Users List
  Consumer[] private waitingQueue;
  Consumer[] private registeredConsumers;

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
  constructor(address _manager) public {
    manager = _manager;
  }

  // Add new Product to the Store
  function addProduct(string memory _productName, uint64 _productPrice) public onlyManager {
    products[totalProducts] = Product(
      _productName,
      _productPrice * ONE_ETH,
      true
    );
    totalProducts += 1;
  }

  // Add new Product to the Store
  function updateProduct(uint32 index, string memory _productName, uint64 _productPrice) public onlyManager {
    products[index] = Product(
      _productName,
      _productPrice * ONE_ETH,
      true
    );
  }

  // Deletes Product at index
  function disabledProduct(uint32 index) public onlyManager {
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
  function requestQueue(uint8 _yearOfBirth) public view {
    // Check If User is already in the Waiting-Queue
    require(canRegisterUser(msg.sender), "Already in Waiting-Queue");

    // Check If User has minimum age of 18
    require(_yearOfBirth <= 2002, "Not Eligible");

    // Check if atleast one Store is Available
    require(totalStores > 0, "No Store(s) Available to register");

    // TODO: Check If User is already
    // Condition to check if user address exist in any of the Store
  }

  // Finds the Store with the smallest Queue
  function findShortestQueue() private view returns(address) {
    uint32 leastQueue = 0;
    uint32 storeIndex = 0;
    for (uint32 i = 0; i < totalStores; i++) {
      if (stores[i]._queueLength <= leastQueue) {
        storeIndex = i;
      }
    }
    return stores[storeIndex]._address;
  }

  function canRegisterUser(address userAddress) private view returns(bool) {
    for (uint i = 0; i < waitingQueue.length; i++) {
      if (waitingQueue[i]._address == userAddress) return false;
    }
    // If not in the Waiting-Queue
    return true;
  }

}