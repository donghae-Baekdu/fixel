import {SafeMath} from "@openzeppelin/contracts/utils/math/SafeMath.sol";

library MathWithSign {
    using SafeMath for uint256;

    function add(
        uint256 a,
        bool aSign,
        uint256 b,
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
        bool aSign,
        uint256 b,
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
}
