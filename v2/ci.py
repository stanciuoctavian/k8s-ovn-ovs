class CI:
    def up(self):
        #pass
        print "UP: Default NOOP"

    def down(self):
       #pass
        print "DOWN: Default NOOP"

    def _prepareTests(self):
        #pass
        print "PREPARE TESTS: Default NOOP"

    def _runTests(self):
        #pass
        print "RUN TESTS: Default NOOP"

    def test(self):
        self._prepareTests()
        self._runTests()