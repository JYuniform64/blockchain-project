var express = require('express');
var router = express.Router();
var contract_address; // contract 'Supply' address
var user; // msg.sender



router.get('/',
function(req, res) {
	res.render('index', {
		title: '合约地址'
	});
});

router.post('/',
function(req, res) {
	contract_address = req.body.contract_address;
	console.log(contract_address);
	res.redirect('/');
});



router.get('/user',
function(req, res) {
	res.render('user', {
		title: '切换用户'
	});
});

router.post('/user',
function(req, res) {
	user = req.body.user;
	console.log(user);
	res.redirect('/user');
});


module.exports = router;
