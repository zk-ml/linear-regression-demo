//
// Copyright 2017 Christian Reitwiessner
// Permission is hereby granted, free of charge, to any person obtaining a copy of this software and associated documentation files (the "Software"), to deal in the Software without restriction, including without limitation the rights to use, copy, modify, merge, publish, distribute, sublicense, and/or sell copies of the Software, and to permit persons to whom the Software is furnished to do so, subject to the following conditions:
// The above copyright notice and this permission notice shall be included in all copies or substantial portions of the Software.
// THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
//
// 2019 OKIMS
//      ported to solidity 0.6
//      fixed linter warnings
//      added requiere error messages
//
//
// SPDX-License-Identifier: GPL-3.0
pragma solidity ^0.6.11;
library Pairing {
    struct G1Point {
        uint X;
        uint Y;
    }
    // Encoding of field elements is: X[0] * z + X[1]
    struct G2Point {
        uint[2] X;
        uint[2] Y;
    }
    /// @return the generator of G1
    function P1() internal pure returns (G1Point memory) {
        return G1Point(1, 2);
    }
    /// @return the generator of G2
    function P2() internal pure returns (G2Point memory) {
        // Original code point
        return G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );

/*
        // Changed by Jordi point
        return G2Point(
            [10857046999023057135944570762232829481370756359578518086990519993285655852781,
             11559732032986387107991004021392285783925812861821192530917403151452391805634],
            [8495653923123431417604973247489272438418190587263600148770280649306958101930,
             4082367875863433681332203403145435568316851327593401208105741076214120093531]
        );
*/
    }
    /// @return r the negation of p, i.e. p.addition(p.negate()) should be zero.
    function negate(G1Point memory p) internal pure returns (G1Point memory r) {
        // The prime q in the base field F_q for G1
        uint q = 21888242871839275222246405745257275088696311157297823662689037894645226208583;
        if (p.X == 0 && p.Y == 0)
            return G1Point(0, 0);
        return G1Point(p.X, q - (p.Y % q));
    }
    /// @return r the sum of two points of G1
    function addition(G1Point memory p1, G1Point memory p2) internal view returns (G1Point memory r) {
        uint[4] memory input;
        input[0] = p1.X;
        input[1] = p1.Y;
        input[2] = p2.X;
        input[3] = p2.Y;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 6, input, 0xc0, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-add-failed");
    }
    /// @return r the product of a point on G1 and a scalar, i.e.
    /// p == p.scalar_mul(1) and p.addition(p) == p.scalar_mul(2) for all points p.
    function scalar_mul(G1Point memory p, uint s) internal view returns (G1Point memory r) {
        uint[3] memory input;
        input[0] = p.X;
        input[1] = p.Y;
        input[2] = s;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 7, input, 0x80, r, 0x60)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require (success,"pairing-mul-failed");
    }
    /// @return the result of computing the pairing check
    /// e(p1[0], p2[0]) *  .... * e(p1[n], p2[n]) == 1
    /// For example pairing([P1(), P1().negate()], [P2(), P2()]) should
    /// return true.
    function pairing(G1Point[] memory p1, G2Point[] memory p2) internal view returns (bool) {
        require(p1.length == p2.length,"pairing-lengths-failed");
        uint elements = p1.length;
        uint inputSize = elements * 6;
        uint[] memory input = new uint[](inputSize);
        for (uint i = 0; i < elements; i++)
        {
            input[i * 6 + 0] = p1[i].X;
            input[i * 6 + 1] = p1[i].Y;
            input[i * 6 + 2] = p2[i].X[0];
            input[i * 6 + 3] = p2[i].X[1];
            input[i * 6 + 4] = p2[i].Y[0];
            input[i * 6 + 5] = p2[i].Y[1];
        }
        uint[1] memory out;
        bool success;
        // solium-disable-next-line security/no-inline-assembly
        assembly {
            success := staticcall(sub(gas(), 2000), 8, add(input, 0x20), mul(inputSize, 0x20), out, 0x20)
            // Use "invalid" to make gas estimation work
            switch success case 0 { invalid() }
        }
        require(success,"pairing-opcode-failed");
        return out[0] != 0;
    }
    /// Convenience method for a pairing check for two pairs.
    function pairingProd2(G1Point memory a1, G2Point memory a2, G1Point memory b1, G2Point memory b2) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](2);
        G2Point[] memory p2 = new G2Point[](2);
        p1[0] = a1;
        p1[1] = b1;
        p2[0] = a2;
        p2[1] = b2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for three pairs.
    function pairingProd3(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](3);
        G2Point[] memory p2 = new G2Point[](3);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        return pairing(p1, p2);
    }
    /// Convenience method for a pairing check for four pairs.
    function pairingProd4(
            G1Point memory a1, G2Point memory a2,
            G1Point memory b1, G2Point memory b2,
            G1Point memory c1, G2Point memory c2,
            G1Point memory d1, G2Point memory d2
    ) internal view returns (bool) {
        G1Point[] memory p1 = new G1Point[](4);
        G2Point[] memory p2 = new G2Point[](4);
        p1[0] = a1;
        p1[1] = b1;
        p1[2] = c1;
        p1[3] = d1;
        p2[0] = a2;
        p2[1] = b2;
        p2[2] = c2;
        p2[3] = d2;
        return pairing(p1, p2);
    }
}
contract Verifier {
    using Pairing for *;
    struct VerifyingKey {
        Pairing.G1Point alfa1;
        Pairing.G2Point beta2;
        Pairing.G2Point gamma2;
        Pairing.G2Point delta2;
        Pairing.G1Point[] IC;
    }
    struct Proof {
        Pairing.G1Point A;
        Pairing.G2Point B;
        Pairing.G1Point C;
    }
    function verifyingKey() internal pure returns (VerifyingKey memory vk) {
        vk.alfa1 = Pairing.G1Point(
            20491192805390485299153009773594534940189261866228447918068658471970481763042,
            9383485363053290200918347156157836566562967994039712273449902621266178545958
        );

        vk.beta2 = Pairing.G2Point(
            [4252822878758300859123897981450591353533073413197771768651442665752259397132,
             6375614351688725206403948262868962793625744043794305715222011528459656738731],
            [21847035105528745403288232691147584728191162732299865338377159692350059136679,
             10505242626370262277552901082094356697409835680220590971873171140371331206856]
        );
        vk.gamma2 = Pairing.G2Point(
            [11559732032986387107991004021392285783925812861821192530917403151452391805634,
             10857046999023057135944570762232829481370756359578518086990519993285655852781],
            [4082367875863433681332203403145435568316851327593401208105741076214120093531,
             8495653923123431417604973247489272438418190587263600148770280649306958101930]
        );
        vk.delta2 = Pairing.G2Point(
            [13211327307662461815384117724387924123583783782469340559269896212011168339377,
             13400554452225773189370087865059785892877429784664503697845330864352241805607],
            [19390556635141615770085521206810911267546120061474143796176300676063928749424,
             6462818410725932517213765695713504275732449110409476304937088516002185838339]
        );
        vk.IC = new Pairing.G1Point[](55);
        
        vk.IC[0] = Pairing.G1Point( 
            17801130273912590327996937892802807004810569882913963856052903091511541451307,
            9300691733562488038671347091480150573370411917486177457823535251339367305373
        );                                      
        
        vk.IC[1] = Pairing.G1Point( 
            11527204344282459515844790678028576801570034493713344438255945197513441979744,
            18782211901590441817412100216435382732831626674754349338840787662231831887422
        );                                      
        
        vk.IC[2] = Pairing.G1Point( 
            10496748559760751295901780246283525797014312416894801758106209431313541967226,
            19271150446384829122240346630624316746611929234709712682023410866658096757620
        );                                      
        
        vk.IC[3] = Pairing.G1Point( 
            2934003521690480387749061867498261134475676033013498491916561137813063570946,
            15899980353130510089612784294752882070871556682538370548572938382060054835449
        );                                      
        
        vk.IC[4] = Pairing.G1Point( 
            14346876060925408028841684098767156466802581471918378512645677229827360063531,
            9448641905636813511493703926233897089643589684559012074859101831602700225762
        );                                      
        
        vk.IC[5] = Pairing.G1Point( 
            14878285429509630495811052300819713550970120457804273859941174817620088885068,
            15694823033868349681868245928737286569953458525482627095565008913516344356081
        );                                      
        
        vk.IC[6] = Pairing.G1Point( 
            14827981527500062982090305482916524619778445193140938514343554165249667927119,
            13082098573835080609614618403952280142468644691836543965269499160000399581072
        );                                      
        
        vk.IC[7] = Pairing.G1Point( 
            16118907922843279494375130031501883964178597588615384455242994510600969659123,
            16130708371172134244026942053028102682522563367636532759130153554338214281161
        );                                      
        
        vk.IC[8] = Pairing.G1Point( 
            15244540779151155577264413736261447438933166994499321902457889775691257601194,
            20057293141091058467066600420955305413386956556492309970785566206905546910910
        );                                      
        
        vk.IC[9] = Pairing.G1Point( 
            6235060571823949400379319700951622672152924601488490346619757056725480394021,
            942219204073007730275584762702393771752984328303475331281775234635849227191
        );                                      
        
        vk.IC[10] = Pairing.G1Point( 
            8107888268081656726886190754947285218415085926982381440242652534349345237302,
            14899650922185333554989098371107092714562988254729893938563175542333721765486
        );                                      
        
        vk.IC[11] = Pairing.G1Point( 
            5576571144303121114931154401758328707768046189136760260284359109982215614769,
            8545276322646382100371872483152229153166743530999462659312122279782004731945
        );                                      
        
        vk.IC[12] = Pairing.G1Point( 
            8359655339775017820321799489964249347906260970087633740751258845249199138614,
            8830396154047497427208864967116393868007518393662525312000062592306407516802
        );                                      
        
        vk.IC[13] = Pairing.G1Point( 
            13623006950347465219753935814097807884835675719480255490229689471259019661320,
            1470057225872659752751213192584663776235173102618731654267720404982419987306
        );                                      
        
        vk.IC[14] = Pairing.G1Point( 
            1496457571004441271255510990392423976224887365514581525745917113064793754848,
            2749566631949885528859484252837658392114403805922208344452995358711376310000
        );                                      
        
        vk.IC[15] = Pairing.G1Point( 
            17780272244352527113715690898149572752534549288932160804792255786008081246525,
            1378161147684919670372317660234266022548044548321477997582953189918014179517
        );                                      
        
        vk.IC[16] = Pairing.G1Point( 
            5447633587255673996941970984975725238438423067723400394604974456097289582154,
            14700734942519900768657357602156092731955192704510486249879205158766314348231
        );                                      
        
        vk.IC[17] = Pairing.G1Point( 
            21117861925487403700630252687571371708711260455273257944326420468146946683967,
            5734766170195380339526619663028513733098492095499174425802306092307166288990
        );                                      
        
        vk.IC[18] = Pairing.G1Point( 
            7516923292324950416774094912777614182598184817273762795200717142592760643178,
            13815426550999009372770438415396663453437825250855107086912768758240695454917
        );                                      
        
        vk.IC[19] = Pairing.G1Point( 
            1022817381985114748887305496715800593222965311108849991236054855092985720974,
            2417153717589722752938703635004435197605206237394923484557288812933917213584
        );                                      
        
        vk.IC[20] = Pairing.G1Point( 
            9552489796927247102085510018551291372508599736331642780240580762270959793742,
            10889776349485286690515205727567786275821688133371219503728013170287141710598
        );                                      
        
        vk.IC[21] = Pairing.G1Point( 
            2895118122569031205869887859499778216333699122426071117880963715020268370273,
            4387110974576194842308346793895278676252632556003839864889581961088484261110
        );                                      
        
        vk.IC[22] = Pairing.G1Point( 
            9182341969529410471388538897466988699538393104396827107445008218293565399804,
            17314905429321366805326994437238565464098809174847426466595493207416842590754
        );                                      
        
        vk.IC[23] = Pairing.G1Point( 
            4261075466599498177801588926504299159620491210006121587993027209507921278260,
            1651720440363418364975638178873307236437197832614330352068401303800262007247
        );                                      
        
        vk.IC[24] = Pairing.G1Point( 
            20044790084635835471882028607799227825783410865468671212761469745666845836762,
            21847050248236115845446735682755000036316396084250403439135530023885803414649
        );                                      
        
        vk.IC[25] = Pairing.G1Point( 
            5622984284093241302888891489206890326872632154910549681831004372787305924683,
            20763413909033943301196939454894449809378797643067328092427651804007475557083
        );                                      
        
        vk.IC[26] = Pairing.G1Point( 
            4906042274052657805786220437420281581310020834945626957034881544981548374717,
            18361261668341799997529477314328704553598490534268429449056499725974508751263
        );                                      
        
        vk.IC[27] = Pairing.G1Point( 
            2463977090662215606486473466887534132052962762544671136047624257594368144407,
            20085427062424799727110184375701444204027791895311198886508341859428360190734
        );                                      
        
        vk.IC[28] = Pairing.G1Point( 
            2346423695568972856095934934897256194111263299492634097521449597990815802697,
            19984299595588622096499621279025867666301626702602002792406447233167458458000
        );                                      
        
        vk.IC[29] = Pairing.G1Point( 
            19765965421652423528085988319852113400327926032930274973112723448970349234628,
            17685779114757866192087791062793602080613211883088896813008974130732169591953
        );                                      
        
        vk.IC[30] = Pairing.G1Point( 
            20538467409779130751385828231984958655954315919548504494690984969421163166583,
            16789769528622888824340222919440860364716754248554630651049595560430422850070
        );                                      
        
        vk.IC[31] = Pairing.G1Point( 
            10593201802958539272942676827056478406457590672268279803738142995942045321135,
            13222211989287152126805939719579789201815687254670628841148482816841607651806
        );                                      
        
        vk.IC[32] = Pairing.G1Point( 
            2893931047901832331793394776554648808399179591033063317275647816907738912191,
            21067385917875923129135451938125829188602164535986892831525456887126174506365
        );                                      
        
        vk.IC[33] = Pairing.G1Point( 
            7011252170253809757621464063304770712865857575706459350848295211677143809364,
            7299989197268316370014607281255048927229900238233773555762185339537914812101
        );                                      
        
        vk.IC[34] = Pairing.G1Point( 
            1289899408103419319083995646717903841646359249373266578726948165363012290946,
            8723302199193264178236373450719360910796799826217423052796204581728477911769
        );                                      
        
        vk.IC[35] = Pairing.G1Point( 
            7148526159980296777973201443996647768784497654633605750633049304549516324392,
            6699305395633239651585193469639786672299799025011873553526034470300803623340
        );                                      
        
        vk.IC[36] = Pairing.G1Point( 
            12720629032752561581165418939676172790817120485398721152660868017698010523608,
            6780422603606528898164138877867332280816130420081633170158885948382642883976
        );                                      
        
        vk.IC[37] = Pairing.G1Point( 
            8082169824935769711049403058337560166539436216950057057470404449499854549071,
            15364370278441072895409177408797923550824713853310713235304837251320929146084
        );                                      
        
        vk.IC[38] = Pairing.G1Point( 
            13347594462568177875048065871726336024596978448704925195397561407572538272042,
            10507057654537845969909200391209790526972511557034439067382426814829260194558
        );                                      
        
        vk.IC[39] = Pairing.G1Point( 
            17384655370801657398366931064009316301159727634729869379487384879094505460263,
            12233517185046447451606487234678845590267868119381442392906292589472993630925
        );                                      
        
        vk.IC[40] = Pairing.G1Point( 
            4638658245291683286020592309923078042932982046235661096211008360464120337137,
            4197220659220536346454911729994760501243908712362380282026872877906293360018
        );                                      
        
        vk.IC[41] = Pairing.G1Point( 
            16043414284973630818457601370448477873931424631853805837795961026437909579658,
            20605595197848660231564487891483359449097908651532867029465740376092569606873
        );                                      
        
        vk.IC[42] = Pairing.G1Point( 
            4889610226088943955596031733452444151484689088440317448520717498747231175721,
            20944505450179651682948697074036936726256632405262612792672093732516234414780
        );                                      
        
        vk.IC[43] = Pairing.G1Point( 
            17291237207677764958700156519104195878302960121012222199095939241022951417388,
            5066222292305483325931629380972739731933903677757619845055914932662867167813
        );                                      
        
        vk.IC[44] = Pairing.G1Point( 
            21865307473186948059782592736468564052667052118498997253594272001097478902497,
            8397787327545851740128427833547337973373008799056371630773379154081552944290
        );                                      
        
        vk.IC[45] = Pairing.G1Point( 
            17339515253163539879402538718866179814796107697739744966248424981930470069814,
            21077267884677059848361401194892394627373357912221699072494211876739220724601
        );                                      
        
        vk.IC[46] = Pairing.G1Point( 
            9177463811515429458880103421381870648482708295705388527951390262438928707883,
            4757981065266721063990839563149382277439753215682927465163727014740172849422
        );                                      
        
        vk.IC[47] = Pairing.G1Point( 
            14878118214683977657279487293675489348131113259887464908331236970318103645274,
            18221357663412478088203533392590696967108949148510195442391586454225264775660
        );                                      
        
        vk.IC[48] = Pairing.G1Point( 
            2905189978076657741301285061288038957550280050760872830573936485065635164401,
            11347203870732386023803476842164699636318210364108546741409356595177348524995
        );                                      
        
        vk.IC[49] = Pairing.G1Point( 
            3521092040551971323584308331480577523656827773088460221580753980411021358968,
            5337137629368248769788966590115973715987645270595565055404723721923982014354
        );                                      
        
        vk.IC[50] = Pairing.G1Point( 
            6828449730727430274041566195202270012049548012919877588315201154484751641679,
            15815067120007951097982655599810494334898852002663043083541829737341449857595
        );                                      
        
        vk.IC[51] = Pairing.G1Point( 
            12488942726037541395030373007892246572935620618474775413828407995319114026597,
            11991321526196646038458826704768482933492510211774572620202756042327209986313
        );                                      
        
        vk.IC[52] = Pairing.G1Point( 
            14409530447551592657363594086803222264743797720068407203962288807624680285717,
            6325241124112200008163127388347253256391398391583157174825657055574000107561
        );                                      
        
        vk.IC[53] = Pairing.G1Point( 
            16734452734599732161593853436620507689368692851324247799199259047059159498396,
            10609872399682692535404682078333652053336563472039801053207169760118374882582
        );                                      
        
        vk.IC[54] = Pairing.G1Point( 
            12850574015551766465513776991074932044200637875141095357180485274321696357753,
            9283129268110732380411293960144718075914805399603516559472877812392621972580
        );                                      
        
    }
    function verify(uint[] memory input, Proof memory proof) internal view returns (uint) {
        uint256 snark_scalar_field = 21888242871839275222246405745257275088548364400416034343698204186575808495617;
        VerifyingKey memory vk = verifyingKey();
        require(input.length + 1 == vk.IC.length,"verifier-bad-input");
        // Compute the linear combination vk_x
        Pairing.G1Point memory vk_x = Pairing.G1Point(0, 0);
        for (uint i = 0; i < input.length; i++) {
            require(input[i] < snark_scalar_field,"verifier-gte-snark-scalar-field");
            vk_x = Pairing.addition(vk_x, Pairing.scalar_mul(vk.IC[i + 1], input[i]));
        }
        vk_x = Pairing.addition(vk_x, vk.IC[0]);
        if (!Pairing.pairingProd4(
            Pairing.negate(proof.A), proof.B,
            vk.alfa1, vk.beta2,
            vk_x, vk.gamma2,
            proof.C, vk.delta2
        )) return 1;
        return 0;
    }
    /// @return r  bool true if proof is valid
    function verifyProof(
            uint[2] memory a,
            uint[2][2] memory b,
            uint[2] memory c,
            uint[54] memory input
        ) public view returns (bool r) {
        Proof memory proof;
        proof.A = Pairing.G1Point(a[0], a[1]);
        proof.B = Pairing.G2Point([b[0][0], b[0][1]], [b[1][0], b[1][1]]);
        proof.C = Pairing.G1Point(c[0], c[1]);
        uint[] memory inputValues = new uint[](input.length);
        for(uint i = 0; i < input.length; i++){
            inputValues[i] = input[i];
        }
        if (verify(inputValues, proof) == 0) {
            return true;
        } else {
            return false;
        }
    }
}
