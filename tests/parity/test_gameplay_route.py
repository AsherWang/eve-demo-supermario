import sys
import unittest
from pathlib import Path
sys.path.insert(0,str(Path(__file__).resolve().parents[2]/"tools/parity"))
from run_gameplay_route import validate_route

class GameplayRouteTest(unittest.TestCase):
    def rows(self):
        return [dict(frame=f,world=2,level=2,state=state,lives=3,dead=False)
                for f,state in enumerate(["world12Intro","playing","levelComplete"])]
    def movie(self): return dict(world=2,level=2,frames=2)
    def test_accepts_complete_normal_route_states(self):
        self.assertTrue(validate_route(self.rows(),self.movie())["passed"])
    def test_rejects_death_even_if_endpoint_reached(self):
        rows=self.rows();rows[1]["dead"]=True
        self.assertFalse(validate_route(rows,self.movie())["passed"])
    def test_rejects_life_loss_and_wrong_stage(self):
        for field,value in [("lives",2),("world",1)]:
            rows=self.rows();rows[1][field]=value
            self.assertFalse(validate_route(rows,self.movie())["passed"])
    def test_rejects_missing_frames_or_missing_endpoint(self):
        rows=self.rows()
        self.assertFalse(validate_route(rows[:-1],self.movie())["passed"])
        rows[2]["state"]="playing"
        self.assertFalse(validate_route(rows,self.movie())["passed"])
    def test_rejects_reordered_frames(self):
        rows=self.rows();rows[1]["frame"]=2
        self.assertFalse(validate_route(rows,self.movie())["passed"])
    def test_accepts_expected_next_level_but_not_skipped_level(self):
        rows=self.rows();rows[2].update(level=3,state="playing")
        self.assertTrue(validate_route(rows,self.movie())["passed"])
        rows[2]["level"]=4
        self.assertFalse(validate_route(rows,self.movie())["passed"])
