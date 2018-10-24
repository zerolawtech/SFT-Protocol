pragma solidity ^0.4.24;

import "../../open-zeppelin/SafeMath.sol";
import "../ModuleBase.sol";
import "../../Custodian.sol";

/* contract ExchangeReserve is IssuerModuleBase {

	using SafeMath64 for uint64;

	struct Country {
		mapping (uint8 => uint64) reserved;
		mapping (uint8 => uint64) max;
		mapping (bytes32 => Exchange) exchanges;
	}

	struct Exchange {
		mapping (uint8 => uint64) reserved;
		mapping (uint8 => uint64) max;
	}

	mapping (bytes32 => bool) approved;
	mapping (uint16 => Country) countries;

	modifier onlyExchange() {
		bytes32 _id = Custodian(msg.sender).id();
		require (approved[_id]);
		_;
	}

	function getCountryReserved(
		uint16 _country,
		uint8 _rating
	)
		external
		view
		returns (uint64 _reserved, uint64 _max)
	{
		Country storage c = countries[_country];
		return (c.reserved[_rating], c.max[_rating]);
	}

	function getExchangeReserved(
		bytes32 _id,
		uint16 _country,
		uint8 _rating
	)
		external
		view
		returns (uint64 _reserved, uint64 _max)
	{
		Exchange storage e = countries[_country].exchanges[_id];
		return (e.reserved[_rating], e.max[_rating]);
	}

	function checkTransfer(
		address,
		bytes32,
		bytes32[2] _id,
		uint8[2] _class,
		uint16[2] _country,
		uint256 _value
	)
		external
		view
		returns (bool)
	{
		if (_class[0] != 3 && _class[1] == 1 && issuer.balanceOf(_id[1]) == 0) {
			uint8 _ratingFrom = registrar.getRating(_id[0]);
			uint8 _ratingTo = registrar.getRating(_id[1]);
			bool _remains = issuer.balanceOf(_id[0]) > _value;
			if (_country[0] != _country[1] || _class[0] != 1 || _remains) {
				(uint64 _count, uint64 _limit) = issuer.getCountryInfo(_country[1], 0);
				if (_limit > 0) {
					require (_limit.sub(_count) > countries[_country[1]].reserved[0]);
				}
			}
			if (_country[0] != _country[1] || _class[0] != 1 || _remains || _ratingFrom != _ratingTo) {
				(_count, _limit) = issuer.getCountryInfo(_country[1], _ratingTo);
				if (_limit > 0) {
					require (_limit.sub(_count) > countries[_country[1]].reserved[_rating]);
				}
			}
		} else if (_class[0] == 3    && _class[1] == 1) {
			require (approved[_id[0]]);
			uint8 _rating = registrar.getRating(_id[1]);
			Exchange storage e = countries[_country[1]].exchanges[_id[0]];
			if (issuer.getCountryInvestorLimit(_country[1], _rating) > 0) {
				require (e.reserved[_rating] > 0);
			}
			if (issuer.getCountryInvestorLimit(_country[1], 0) > 0) {
				require (e.reserved[0] > 0);
			}
		} else if (_class[1] == 3) {
			require (approved[_id[1]]);
		}
		return true;
	}

	function transferTokens(
		address,
		bytes32[2] _id,
		uint8[2] _class,
		uint16[2] _country,
		uint256 _value
	)
		external
		onlyParent
		returns (bool)
	{
		if (_class[0] != 3 && _class[1] != 3) return true;
		if (_class[0] == 1 && _class[1] == 3 && issuer.balanceOf(_id[0]) == 0) {
			uint8 _rating = registrar.getRating(_id[0]);
			Country storage c = countries[_country[0]];
			Exchange storage e = c.exchanges[_id[1]];
			if (issuer.getCountryInvestorLimit(_country[0], _rating) > 0) {
				e.reserved[_rating] = e.reserved[_rating].add(1);
				c.reserved[_rating] = c.reserved[_rating].add(1);
			}
			if (issuer.getCountryInvestorLimit(_country[0], 0) > 0) {
				e.reserved[0] = e.reserved[0].add(1);
				c.reserved[0] = c.reserved[0].add(1);
			}
		}
		if (_class[0] == 3 && _class[1] == 1 && issuer.balanceOf(_id[1]) == _value) {
			_rating = registrar.getRating(_id[1]);
			c = countries[_country[1]];
			e = c.exchanges[_id[1]];
			if (issuer.getCountryInvestorLimit(_country[1], _rating) > 0) {
				e.reserved[_rating] = e.reserved[_rating].sub(1);
				c.reserved[_rating] = c.reserved[_rating].sub(1);
			}
			if (issuer.getCountryInvestorLimit(_country[1], 0) > 0) {
				e.reserved[0] = e.reserved[0].sub(1);
				c.reserved[0] = c.reserved[0].sub(1);
			}
		}
	}

	function _min(uint64 a, uint64 b) internal pure returns (uint64) {
		if (a <= b) return a;
		return b;
	}

	function exchangeReserve(
		uint16 _country,
		uint8 _rating
	)
		external
		onlyExchange
		returns (uint64)
	{
		bytes32 _id = registrar.getId(msg.sender);
		Country storage c = countries[_country];
		Exchange storage e = c.exchanges[_id];
		if (
			c.max[_rating] > 0 &&
			c.max[_rating] > c.reserved[_rating] &&
			e.max[_rating] > e.reserved[_rating]
		) {
			(uint64 _count, uint64 _limit) = issuer.getCountryInfo(_country, _rating);
			uint64 _avail = _min(
				_limit.sub(_count).sub(c.reserved[_rating]),
				c.max[_rating].sub(c.reserved[_rating])
			);
			if (_avail > e.reserved[_rating]) {
				uint64 _inc = _min(_avail, e.max[_rating]).sub(e.reserved[_rating]);
				e.reserved[_rating] = e.reserved[_rating].add(_inc);
				c.reserved[_rating] = c.reserved[_rating].add(_inc);
			}
		}
		return e.reserved[0];
	}

	function exchangeRelease(
		uint16 _country,
		uint8 _rating,
		uint64 _value
	)
		public
		onlyExchange
		returns (bool)
	{
		return _releaseExchange(
			registrar.getId(msg.sender),
			_country,
			_rating,
			_value
		);
	}

	function exchangeReleaseMany(
		uint16[] _country,
		uint8[] _rating,
		uint64[] _value
	)
		external
		onlyExchange
		returns (bool)
	{
		require (
			_country.length == _rating.length &&
			_country.length == _value.length
		);
		bytes32 _id = registrar.getId(msg.sender);
		for (uint256 i = 0; i < _country.length; i++) {
			_releaseExchange(_id, _country[i], _rating[i], _value[i]);
		}
		return true;
	}

	function issuerRelease(
		bytes32 _id,
		uint16 _country,
		uint8 _rating,
		uint64 _value
	)
		external
		onlyIssuer
		returns (bool)
	{
		return _releaseExchange(_id, _country, _rating, _value);
	}

	function issuerReleaseMany(
		bytes32 _id,
		uint16[] _country,
		uint8[] _rating,
		uint64[] _value
	)
		external
		onlyIssuer
		returns (bool)
	{
		require (
			_country.length == _rating.length &&
			_country.length == _value.length
		);
		for (uint256 i = 0; i < _country.length; i++) {
			_releaseExchange(_id, _country[i], _rating[i], _value[i]);
		}
	}

	function _releaseExchange(
		bytes32 _id,
		uint16 _country,
		uint8 _rating,
		uint64 _value
	)
		internal
		returns (bool)
	{
		Country storage c = countries[_country];
		Exchange storage e = c.exchanges[_id];
		_value = _min(_value, e.reserved[_rating]);
		c.reserved[_rating] = c.reserved[_rating].sub(_value);
		e.reserved[_rating] = e.reserved[_rating].sub(_value);
		return true;
	}

} */
