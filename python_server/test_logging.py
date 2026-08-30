import unittest

class ClientIPTests(unittest.TestCase):
    def test_get_client_ip_from_xff(self):
        class D: pass
        d = D()
        d.headers = {'X-Forwarded-For': '1.2.3.4, 10.0.0.1'}
        d.client_address = ('10.0.0.1', 12345)
        from server import Handler
        self.assertEqual(Handler.get_client_ip(d), '1.2.3.4')

    def test_get_client_ip_from_x_real_ip(self):
        class D: pass
        d = D()
        d.headers = {'X-Real-IP': '5.6.7.8'}
        d.client_address = ('10.0.0.1', 12345)
        from server import Handler
        self.assertEqual(Handler.get_client_ip(d), '5.6.7.8')

    def test_get_client_ip_fallback(self):
        class D: pass
        d = D()
        d.headers = {}
        d.client_address = ('10.0.0.1', 12345)
        from server import Handler
        self.assertEqual(Handler.get_client_ip(d), '10.0.0.1')


if __name__ == '__main__':
    unittest.main()
