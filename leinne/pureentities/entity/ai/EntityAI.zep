namespace leinne\pureentities\entity\ai;

use pocketmine\block\Block;
use pocketmine\block\Door;
use pocketmine\block\Lava;
use pocketmine\block\Stair;
use pocketmine\block\Trapdoor;
use pocketmine\block\WoodenDoor;
use pocketmine\math\Facing;
use pocketmine\math\Math;
use pocketmine\math\Vector3;
use pocketmine\world\Position;
class EntityAI
{
    const WALL = 0;
    const PASS = 1;
    const BLOCK = 2;
    const SLAB = 3;
    const UP_SLAB = 4;
    const DOOR = 5;
    public static function getHash(<Vector3> pos) -> string
    {
        var pos;
        let pos = self::getFloorPos(pos);
        return "{pos->x}:{pos->y}:{pos->z}";
    }

    public static function getFloorPos(<Vector3> pos) -> <Position>
    {
        var newPos;
        let newPos = new Position(Math::floorFloat(pos->x), pos->getFloorY(), Math::floorFloat(pos->z));
        if (pos instanceof Position) {
            let newPos->world = pos->world;
        }
        return newPos;
    }

    /**
     * 특정 블럭이 어떤 상태인지를 확인해주는 메서드
     *
     * @param Block|Position $data
     *
     * @return int
     */
    public static function checkBlockState(var data) -> int
    {
        var boxDiff;
        var blockBox;
        var value;
        var block;
        var floor;
        if (data instanceof Position) {
            let floor = self::getFloorPos(data);
            let block = data->world->getBlockAt(floor->x, floor->y, floor->z);
        } elseif (data instanceof Block) {
            let block = data;
        } else {
            throw new \RuntimeException("{data} is not Block|Position class");
        }
        let value = EntityAI::BLOCK;
        if (block instanceof Door && count(block->getAffectedBlocks()) > 1) {
            //문일때
            let value = block instanceof WoodenDoor ? EntityAI::DOOR : EntityAI::WALL;
            //철문인지 판단
        } elseif (block instanceof Stair) {
            //TODO: 계단 위치에 따라 변경
            /*$blockBoxes = $block->getCollisionBoxes();
                        if(count($blockBoxes) < 3){
                            $pos = $block->getPos();
                            foreach($blockBoxes as $_ => $bb){
            
                            }
                        }*/
        } else {
            let blockBox = isset(block->getCollisionBoxes()[0]) ? block->getCollisionBoxes()[0] : null;
            let boxDiff = blockBox === null ? 0 : blockBox->maxY - blockBox->minY;
            if (boxDiff <= 0) {
                if (block instanceof Lava) {
                    //통과 가능 블럭중 예외처리
                    let value = EntityAI::WALL;
                } else {
                    let value = EntityAI::PASS;
                }
            } elseif (boxDiff > 1) {
                //울타리라면
                let value = EntityAI::WALL;
            } elseif (boxDiff <= 0.5) {
                //반블럭/카펫/트랩도어 등등
                let value = blockBox->minY == (int) blockBox->minY ? EntityAI::SLAB : EntityAI::UP_SLAB;
            }
        }
        return block instanceof Trapdoor ? EntityAI::PASS : value;
        //TODO: 트랩도어, 카펫 등
    }

    /**
     * 블럭이 통과 가능한 위치인지를 판단하는 메서드
     *
     * @param Position $pos
     * @param Block|null $block
     *
     * @return int
     */
    public static function checkPassablity(<Position> pos, ?Block block = null) -> int
    {
        var up2;
        var upBlock;
        var up;
        var state;
        var block;
        var floor;
        if (block === null) {
            let floor = self::getFloorPos(pos);
            let block = pos->world->getBlockAt(floor->x, floor->y, floor->z);
        } else {
            let floor = block->getPos();
        }
        let state = self::checkBlockState(block);
        //현재 위치에서의 블럭 상태가
        switch (state) {
            case EntityAI::WALL:
            case EntityAI::DOOR:
                //벽이거나 문이라면 체크가 더이상 필요 없음
                return state;
            case EntityAI::PASS:
                //통과가능시에
                //윗블럭도 통과 가능하다면 통과판정 아니라면 벽 판정
                return self::checkBlockState(floor->getSide(Facing::UP)) === EntityAI::PASS ? EntityAI::PASS : EntityAI::WALL;
            case EntityAI::BLOCK:
            case EntityAI::UP_SLAB:
                //블럭이거나 위에 설치된 반블럭일경우
                let up = self::checkBlockState(let upBlock = block->getSide(Facing::UP));
                //y+1의 블럭이
                if (up === EntityAI::SLAB) {
                    //반블럭 이고
                    let up2 = self::checkBlockState(floor->getSide(Facing::UP, 2));
                    //그 위가 통과 가능하며 블럭의 최고점과 자신의 위치의 차가 블럭 이하라면 블럭 판정
                    return up2 === EntityAI::PASS && upBlock->getCollisionBoxes()[0]->maxY - pos->y <= 1 ? EntityAI::BLOCK : EntityAI::WALL;
                } elseif (up === EntityAI::PASS) {
                    //통과가능시에
                    //y+ 2도 통과 가능이라면
                    return self::checkBlockState(floor->getSide(Facing::UP, 2)) === EntityAI::PASS ? block->getCollisionBoxes()[0]->maxY - pos->y <= 0.5 ? EntityAI::SLAB : EntityAI::BLOCK : EntityAI::WALL;
                }
                return EntityAI::WALL;
            case EntityAI::SLAB:
                return self::checkBlockState(floor->getSide(Facing::UP)) === EntityAI::PASS && ((let up = self::checkBlockState(floor->getSide(Facing::UP, 2))) === EntityAI::PASS || up === EntityAI::UP_SLAB) ? EntityAI::SLAB : EntityAI::WALL;
        }
        return EntityAI::WALL;
    }

    /**
     * 현재 위치에서 도달하게 될 최종 Y좌표를 계산합니다
     *
     * @param Position $pos
     *
     * @return float
     */
    public static function calculateYOffset(<Position> pos) -> float
    {
        var state;
        var block;
        var newPos;
        var newY;
        let newY = (int) pos->y;
        switch (EntityAI::checkBlockState(pos)) {
            case EntityAI::BLOCK:
                let newY += 1;
                break;
            case EntityAI::SLAB:
                let newY += 0.5;
                break;
            case EntityAI::PASS:
                let newPos = self::getFloorPos(pos);
                let newPos->y -= 1;
                for (; newPos->y >= 0; let newPos->y -= 1) {
                    let block = pos->world->getBlockAt(newPos->x, newPos->y, newPos->z);
                    let state = EntityAI::checkBlockState(block);
                    if (state === EntityAI::UP_SLAB || state === EntityAI::BLOCK || state === EntityAI::SLAB) {
                        var _;
var bb;
for _, bb in block->getCollisionBoxes() {
                            if (newPos->y < bb->maxY) {
                                let newPos->y = bb->maxY;
                            }
                        }
                        break;
                    }
                }
                let newY = newPos->y;
                break;
        }
        return newY;
    }

}