contract Coin {
    
    address owner;
    uint public totalSupply;
    
    mapping (address => uint) public balances;
    
    // indexed allows to search through addresses
    event Transfer(address indexed _to, address indexed _from, uint _value);
    // how many new coins have been created and now exist
    event NewCoinLog(address _to, uint _amount, uint _newSupply);
    
    // to insure only owner can execute mint function
    modifier onlyOwner() {
        if(msg.sender != owner){
            trow;
        } else {
            // tells modifier func that all good. this syntax is required
            _;
        }
    }
    
    function Coin(uint _supply) {
        owner = msg.sender;
        totalSupply = _supply;
        balances[owner] += _supply;
    }
    
    function getBalance(address _addr) constant returns (uint) {
        return balances[_addr];
    }
    
    function transfer(address _to, uint _amount) returns (bool) {
        if(balances[msg.sender] < _amount) throw;
        balaces[msg.sender] -= _amount;
        balaces[_to] += _amount;
        Transfer(_to, msg.sender, _amount);
        return true;
    }
    
    function mint(unit _amount) onlyOwner returns (bool) {
        totalSupply += _amount;
        balaces[owner] += _amount;
        NewCoinLog(owner, _amount, totalSupply)
        return true;
    }
    
    // to disable contract
    function disable() onlyOwner {
        // built-in func. automatically sends remaining ETH to specified addr
        selfdestruct(owner);
    }
}
