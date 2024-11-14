#!/bin/env python
from argparse import ArgumentParser

from PhysicsTools.NanoAODTools.postprocessing.framework.postprocessor import PostProcessor
from PhysicsTools.NanoAODTools.postprocessing.framework.datamodel import Collection
from PhysicsTools.NanoAODTools.postprocessing.framework.eventloop import Module
from PhysicsTools.NanoAODTools.postprocessing.tools import deltaR

class Skimmer(Module):
    def __init__(self):
        pass

    @staticmethod
    def selectMuon(muon):
        '''Select muon passing analysis criteria
        '''
        return muon.pt > 20. and abs(muon.eta) < 2.4 and muon.looseId

    @staticmethod
    def selectElectron(ele):
        '''Select muon passing analysis criteria, without isolation
        '''
        return ele.pt > 20. and abs(ele.eta) < 2.5 and ele.cutBased >= 1

    def analyze(self, event):
        """process event, return True (go to next module) or False (fail, go to next event)"""
        muons = Collection(event, 'Muon')
        muons = [muon for muon in muons if self.selectMuon(muon)]
        muons.sort(key=lambda x: x.pt, reverse=True)

        electrons = Collection(event, 'Electron')
        electrons = [electron for electron in electrons if self.selectElectron(electron)]
        electrons = [electron for electron in electrons if not any(deltaR(electron, muon) < 0.5 for muon in muons)]
        electrons.sort(key=lambda x: x.pt, reverse=True)

        return len(muons) + len(electrons) >= 1

if __name__ == "__main__":
    parser = ArgumentParser(description='Run the NanoAOD skimmer.')
    parser.add_argument('inFiles', nargs="+", default="", help="Comma-separated list of input files")
    parser.add_argument('--out', action="store", dest="outDir", default="./", help="Output directory")
    parser.add_argument('--keepdrop', action="store", dest="keepDropFile", default="keep_and_drop_skim.txt", help="Branches keep and drop file")
    parser.add_argument('--tag', dest='tag', default='skim')
    parser.add_argument('--cache', type=str, default='root://cms-xrd-global.cern.ch/', help='Path to the cache')
    args = parser.parse_args()

    inFiles = ','.join(args.inFiles).replace("\"", "").split(',')
    inFiles = [args.cache + f if f.startswith('/store') else f for f in inFiles]
    outputDir = args.outDir
    keepDropFile = args.keepDropFile

    modules = [Skimmer()]

    p = PostProcessor(outputDir, 
                    inFiles, 
                    outputbranchsel=keepDropFile,
                    modules=modules, 
                    provenance=False, 
                    fwkJobReport=False,
                    postfix=args.tag, 
                    maxEntries=None)

    p.run()