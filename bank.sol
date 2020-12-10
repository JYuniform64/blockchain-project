pragma solidity >= 0.4.24 < 0.6.11;

contract Bank
{
    address bank;//银行地址
    mapping(address => uint) public balance;
    mapping(address => uint) public credit;                          //更改
    function check_balance(address a) public returns(uint)
    {
        return balance[a];
    }
    function check_credit(address a) public returns(uint)
    {
        return credit[a];
    }
    //现在的时间
    uint public now_time = 0;

    //合同
    struct Trust_contract {
        uint start_time; //合同开始时间
        uint end_time;  //合同结束时间
        address address_from;  //合同的from方
        address address_to;  //合同的to方
        uint total;  //合同总额度
        uint used;  //被使用的额度
    }
    Trust_contract[] public contracts;

    constructor()public
    {
        bank = msg.sender;
        balance[msg.sender] = 999999;
    }

    function deposit(uint money) public
    {
        balance[msg.sender] += money;
    }

    //签署信任合同的函数
    function trusted(uint end_time, uint money, uint password) public
    {
        if(password != 12345678) return ; //判断密码是否正确
        if(bank == 0x0000000000000000000000000000000000000000) return ; //判断银行是否存在
        if(end_time < now_time) return ; //判断时间是否合理
        //添加信任合同
        Trust_contract memory t = Trust_contract(now_time, end_time, bank, msg.sender, money, 0);
        contracts.push(t);
    }

    //应收账款的转让
    function transfer(address payee, uint money) public returns (bool) {
        require(payee == bank, "Can't transfer to bank");

        //检查额度是否充足
        uint total_available = 0;
        bool enough = false;
        for(uint i = 0; i < constructor.length; i++) {
            if(constructor[i].payee == msg.sender) 
                total_available += (contracts[i].total - contracts[i].used);
            if(total_available >= money) {
                enough = true;
                break;
            }
        }
        if(total_available < money)
            return false;
        
        //开始转让，遍历所有合同，扣除转让方持有合同中的余额
        for(uint i = 0; i < constructor.length; i++) {
            if(contracts[i].address_to == msg.sender) {
                //如果一份合同的余额足够，直接给这份合同的used加上money，并新建一份额度为money的普通合同，结束遍历
                if(contracts[i].total - contracts[i].used >= money) {
                    contracts[i].used += money;
                    Trust_contract memory t = Trust_contract(now_time, contracts[i].end_time, contracts[i].address_from, payee, money, 0);
                    contracts.push(t);
                    break;
                } else {
                    money -= contracts[i].total - contracts[i].used;
                    Trust_contract memory t = Trust_contract(now_time, contracts[i].end_time, contracts[i].address_from, payee, contracts[i].total-contracts[i].used, 0);
                    contracts.push(t);
                    contracts[i].used = contracts[i].total;
                }
            }
        }
        return true;
    }

    //企业从银行贷款或者融资的函数
    function load(uint money)public
    {
        //判断交易的to方是不是bank，如果是则终止交易
        if(msg.sender == bank) return ;
        //判断交易的发起者信用度，如果小于60，则终止交易
        if(credit[msg.sender] < 60) return ;
        uint mount = 0; //mount用于储存总余额
        bool flag = false;
        for(uint i = 0; i < contracts.length; i++)
        {
            if(contracts[i].address_to == msg.sender)
                mount += (contracts[i].total - contracts[i].used);
            if(mount >= money)
            {
                flag = true;
                break;
            }
        }
        if(flag == false) return; //余额不足终止交易

        //开始贷款，遍历所有合同，合同的to方才有权利使用这份余额
        //money是用户的输入值，代表msg.sender想贷款的额度
        for(uint i = 0; i < contracts.length; i++)
        {
            if(contracts[i].address_to == msg.sender)
            {
                //如果一份合同的余额足够，直接给这份合同的used加上money，并给msg.sender的账户加上money，结束遍历
                if(contracts[i].total - contracts[i].used >= money)
                {
                    contracts[i].used += money;
                    balance[msg.sender] += money;
                    balance[bank] -= money;
                    break;
                }
                //如果一份合同的余额不足，就用光余额，并给msg.sender的账户加上money，更新money用于下一个循环
                else
                {
                    money -= (contracts[i].total - contracts[i].used);
                    balance[msg.sender] += money;
                    balance[bank] -= money;
                    contracts[i].used = contracts[i].total;
                }
            }
        }
    }

    //mount用于存储总欠款
    mapping(address => uint) mount;
    //企业还款函数 + 日期更新函数
    function repay(uint time) public
    {
        //判断前进的日期是否大于现在的日期
        if(time <= now_time) return ;
        //初始化mount
        for(uint i = 0; i < contracts.length; i++)
        {
            mount[contracts[i].address_to] = 0;
        }
        //计算总欠款
        for(i = 0; i < contracts.length; i++)
        {
            if(contracts[i].end_time < time)
            {
                if(contracts[i].address_from == bank)
                {
                    mount[contracts[i].address_to] += contracts[i].used;
                }
            }
        }
        //比较总欠款和账户存款，如果存款不够就不能还款，更新日期
        for(i = 0; i < contracts.length; i++)
        {
            if(mount[contracts[i].address_to] > balance[contracts[i].address_to])
            {
                credit[contracts[i].address_to] -= 10;
                return ;
            }
        }
        for(i = 0; i < contracts.length; i++)
        {
            if(contracts[i].end_time < time)
            {
                //如果合同的from方是bank，这是一份信任合同，就从to方的账户上扣钱
                if(contracts[i].address_from == bank)
                {
                    balance[contracts[i].address_to] -= contracts[i].used;
                    //删除合同
                    delete contracts[i];
                }
                //如果这是一份普通合同，就在to的账户上加钱
                else
                {
                    balance[contracts[i].address_to] += (contracts[i].total - contracts[i].used);
                    delete contracts[i]; //删除合同
                }
            }
        }
        now_time = time;
    }

}