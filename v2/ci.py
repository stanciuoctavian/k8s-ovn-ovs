import logging

class CI(object):
    def up(self):
        #pass
        logging.info("UP: Default NOOP")

    def down(self):
       #pass
        logging.info("DOWN: Default NOOP")

    def _prepareTests(self):
        #pass
        logging.info("PREPARE TESTS: Default NOOP")

    def _runTests(self):
        #pass
        logging.info("RUN TESTS: Default NOOP")

    def test(self):
        self._prepareTests()
        self._runTests()
