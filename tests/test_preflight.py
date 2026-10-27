import importlib.util, pathlib, unittest
spec=importlib.util.spec_from_file_location('p',pathlib.Path(__file__).parents[1]/'scripts/preflight.py'); p=importlib.util.module_from_spec(spec);spec.loader.exec_module(p)
class Modes(unittest.TestCase):
 def test_lite_no_kvm(self): self.assertEqual(p.choose('AUTO',3900,100,False,False),'LITE')
 def test_full(self): self.assertEqual(p.choose('AUTO',7900,100,True,True),'FULL')
 def test_bad_full(self):
  for vals in [(3900,100,True,True),(16000,30,True,True),(16000,100,False,True),(16000,100,True,False)]:
   with self.assertRaises(ValueError):p.choose('FULL',*vals)
 def test_explicit_lite(self): self.assertEqual(p.choose('LITE',16000,100,True,True),'LITE')
 def test_small(self):
  with self.assertRaises(ValueError):p.choose('AUTO',2000,100,False,False)
if __name__=='__main__':unittest.main()
