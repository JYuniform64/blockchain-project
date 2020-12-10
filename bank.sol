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
        bool valid; //合同是否有余额
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
        Trust_contract memory t = Trust_contract(now_time, end_time, bank, msg.sender, money, 0, true);
        contracts.push(t);
    }

    //检查账户中应收账款的总量是否大于某个值
    function check_balance_enough(address a, uint money) private returns (bool) {
        uint total_available = 0;
        bool enough = false;
        for(uint i = 0; i < contracts.length; i++) {
            if(contracts[i].to == a) 
                total_available += (contracts[i].total - contracts[i].used);
            if(total_available >= money) {
                enough = true;
                break;
            }
        }
        if(total_available < money)
            return false;
        else 
            return true;
    }
    
    //应收账款的转让
    function transfer(address payee, uint money) public returns (bool) {
        require(payee == bank, "Can't transfer to bank");
        if(check_balance_enough(msg.sender, money) == false)
            return false;

        //开始转让，遍历所有合同，扣除转让方持有合同中的余额
        for(uint i = 0; i < contracts.length; i++) {
            if(contracts[i].valid && contracts[i].address_to == msg.sender) {
                //如果一份合同的余额足够，则扣除后结束遍历
                if(contracts[i].total - contracts[i].used >= money) {
                    contracts[i].used += money;
                    Trust_contract memory t = Trust_contract(now_time, contracts[i].end_time, contracts[i].address_from, payee, money, 0, true);
                    contracts.push(t);
                    break;
                } else {    //如果一份合同的余额不足，则扣除后继续遍历
                    money -= contracts[i].total - contracts[i].used;
                    Trust_contract memory t = Trust_contract(now_time, contracts[i].end_time, contracts[i].address_from, payee, contracts[i].total-contracts[i].used, 0, true);
                    contracts.push(t);
                    contracts[i].used = contracts[i].total;
                    contracts[i].valid = false;
                }
            }
        }
        return true;
    }

    //企业从银行融资.注意这里的融资仅依据企业持有的应收账款额度，不依赖于企业本身的信用度。
    function loan(uint money)public returns (bool) {
        require(msg.sender != bank, "Illegal loan as bank!");
        if(check_balance_enough(msg.sender, money) == false)
            return false;

        //遍历所有合同，
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