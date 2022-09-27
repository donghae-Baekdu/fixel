import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

library MathUtil {
    using SafeMath for uint8;
    using SafeMath for uint256;

    function add(
        uint256 a,
        uint256 b,
        bool aSign,
        bool bSign
    ) external pure returns (uint256 _c, bool _cSign) {
        if (aSign == bSign) {
            _c = a.add(b);
            _cSign = aSign;
        } else {
            if (a >= b) {
                _c = a.sub(b);
                _cSign = aSign;
            } else {
                _c = b.sub(a);
                _cSign = bSign;
            }
        }
    }

    function sub(
        uint256 a,
        uint256 b,
        bool aSign,
        bool bSign
    ) external pure returns (uint256 _c, bool _cSign) {
        if (aSign != bSign) {
            _c = a.add(b);
            _cSign = aSign;
        } else {
            if (a >= b) {
                _c = a.sub(b);
                _cSign = aSign;
            } else {
                _c = b.sub(a);
                _cSign = bSign;
            }
        }
    }

    function mul(
        uint256 a,
        uint256 b,
        uint8 aDecimals,
        uint8 bDecimals,
        uint8 cDecimals
    ) external pure returns (uint256 _c) {
        // TODO
        uint8 decimalsSum = aDecimals + bDecimals;
        if (decimalsSum >= cDecimals) {
            _c = a.mul(b).div(10**(decimalsSum.sub(cDecimals)));
        } else {
            _c = a.mul(b).mul(10**(cDecimals.sub(decimalsSum)));
        }
    }

    function div(
        uint256 a,
        uint256 b,
        uint8 aDecimals,
        uint8 bDecimals,
        uint8 cDecimals
    ) external pure returns (uint256 _c) {
        // TODO
        uint8 decimalsSum = aDecimals + bDecimals;
        if (decimalsSum >= cDecimals) {
            _c = a.mul(b).div(10**(decimalsSum.sub(cDecimals)));
        } else {
            _c = a.mul(b).mul(10**(cDecimals.sub(decimalsSum)));
        }
    }

    function convertDecimals(
        uint256 a,
        uint8 fromDecimals,
        uint8 toDecimals
    ) external pure returns (uint256 _b) {
        if (fromDecimals >= toDecimals) {
            _b = a.div(10**(fromDecimals.sub(toDecimals)));
        } else {
            _b = a.mul(10**(toDecimals.sub(fromDecimals)));
        }
    }
}
