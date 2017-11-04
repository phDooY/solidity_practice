pragma solidity 0.4.17;

contract helloWorld {
    
    string public message;

    function helloWorld() {
        message = "hello world";
    }

    function sayHi() constant returns (string){
        return message;
    }
}


// string
// contract helloWorld { string public message; function helloWorld() { message = "hello world"; } function sayHi() constant returns (string){ return message; } }


/*
> var data = compiled.contracts[':helloWorld'].bytecode

> var abi = JSON.parse(compiled.contracts[':helloWorld'].interface)

> var helloWorldContract = web3.eth.contract(abi)

> var deployed = helloWorldContract.new({
... from: acct1,
... data: data,
... gas: 4700000, // find out from online compiler
... gasPrice: 1   // when deploying to main network, check current as price at ethstats
... }, (error, contract) => {} )
undefined
> deployed.sayHi();
'hello world'

*/